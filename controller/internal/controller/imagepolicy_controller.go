/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	securityv1 "github.com/jonlimpw/chainguard-controller/api/v1"
	"github.com/jonlimpw/chainguard-controller/internal/rekor"
)

// DockerHubManifest represents the Docker Hub registry manifest response
type DockerHubManifest struct {
	MediaType     string `json:"mediaType"`
	SchemaVersion int    `json:"schemaVersion"`
	Config        struct {
		Digest string `json:"digest"`
	} `json:"config"`
}

// DockerHubToken represents the Docker Hub authentication token
type DockerHubToken struct {
	Token string `json:"token"`
}

// ImagePolicyReconciler reconciles a ImagePolicy object
type ImagePolicyReconciler struct {
	client.Client
	Scheme      *runtime.Scheme
	Recorder    record.EventRecorder
	RekorClient *rekor.Client
}

// +kubebuilder:rbac:groups=security.chainguard.dev,resources=imagepolicies,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=security.chainguard.dev,resources=imagepolicies/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=security.chainguard.dev,resources=imagepolicies/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;update;patch
// +kubebuilder:rbac:groups="",resources=events,verbs=create;patch
// +kubebuilder:rbac:groups="",resources=namespaces,verbs=get;list;watch

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
func (r *ImagePolicyReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)
	log.Info("=== RECONCILE STARTED ===", "namespacedName", req.NamespacedName)

	// Fetch the ImagePolicy instance
	imagePolicy := &securityv1.ImagePolicy{}
	if err := r.Get(ctx, req.NamespacedName, imagePolicy); err != nil {
		if errors.IsNotFound(err) {
			log.Info("ImagePolicy resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		log.Error(err, "Failed to get ImagePolicy")
		return ctrl.Result{}, err
	}

	// Set default values if not specified
	checkInterval := int32(60) // 1 minute default (demo-friendly)
	if imagePolicy.Spec.CheckIntervalSeconds != nil {
		checkInterval = *imagePolicy.Spec.CheckIntervalSeconds
	}

	enforceLatest := true
	if imagePolicy.Spec.EnforceLatestDigest != nil {
		enforceLatest = *imagePolicy.Spec.EnforceLatestDigest
	}

	// Check if we need to fetch the latest digest
	now := metav1.Now()
	shouldCheck := imagePolicy.Status.LastChecked == nil ||
		now.Time.Sub(imagePolicy.Status.LastChecked.Time) > time.Duration(checkInterval)*time.Second

	var latestDigest string
	var err error

	if shouldCheck {
		log.Info("Fetching latest digest from DockerHub", "repository", imagePolicy.Spec.Repository)
		latestDigest, err = r.getLatestDigestFromDockerHub(ctx, imagePolicy.Spec.Repository)
		if err != nil {
			log.Error(err, "Failed to fetch latest digest from DockerHub")
			r.updateCondition(imagePolicy, securityv1.ConditionTypeDegraded, metav1.ConditionTrue,
				"DockerHubError", fmt.Sprintf("Failed to fetch digest: %v", err))
			imagePolicy.Status.ComplianceStatus = securityv1.ComplianceStatusError
		} else {
			imagePolicy.Status.LatestDigest = latestDigest
			imagePolicy.Status.LastChecked = &now
			log.Info("Successfully fetched latest digest", "digest", latestDigest)
		}
	} else {
		latestDigest = imagePolicy.Status.LatestDigest
	}

	// Find deployments to monitor
	deployments, err := r.findDeploymentsToMonitor(ctx, imagePolicy)
	if err != nil {
		log.Error(err, "Failed to find deployments to monitor")
		return ctrl.Result{}, err
	}

	// Analyze compliance
	deploymentStatuses := []securityv1.DeploymentStatus{}
	compliantCount := int32(0)

	for _, deployment := range deployments {
		log.Info("Processing deployment", "deployment", deployment.Name, "namespace", deployment.Namespace, "enforceLatest", enforceLatest)
		status := r.analyzeDeploymentCompliance(ctx, deployment, imagePolicy.Spec.Repository, latestDigest, enforceLatest, imagePolicy.Spec.AttestationPolicy)
		deploymentStatuses = append(deploymentStatuses, status)
		log.Info("Deployment compliance status", "deployment", deployment.Name, "isCompliant", status.IsCompliant)
		if status.IsCompliant {
			compliantCount++
		} else if enforceLatest {
			// Create event for non-compliant deployment
			r.Recorder.Event(imagePolicy, corev1.EventTypeWarning, "NonCompliantImage",
				fmt.Sprintf("Deployment %s/%s is using outdated image digest", deployment.Namespace, deployment.Name))

			// Debug logging for auto-remediation conditions
			hasAutomation := r.hasAutomationEnabled(deployment)
			hasLatestDigest := latestDigest != ""
			log.Info("Checking auto-remediation conditions",
				"deployment", deployment.Name,
				"namespace", deployment.Namespace,
				"hasAutomation", hasAutomation,
				"hasLatestDigest", hasLatestDigest,
				"latestDigest", latestDigest)

			// Check if deployment has automation enabled
			if hasAutomation && hasLatestDigest {
				log.Info("Auto-remediation enabled for deployment", "deployment", deployment.Name, "namespace", deployment.Namespace)
				if err := r.remediateDeployment(ctx, deployment, imagePolicy.Spec.Repository, latestDigest); err != nil {
					log.Error(err, "Failed to auto-remediate deployment", "deployment", deployment.Name, "namespace", deployment.Namespace)
					r.Recorder.Event(imagePolicy, corev1.EventTypeWarning, "AutoRemediationFailed",
						fmt.Sprintf("Failed to auto-remediate deployment %s/%s: %v", deployment.Namespace, deployment.Name, err))
				} else {
					log.Info("Successfully auto-remediated deployment", "deployment", deployment.Name, "namespace", deployment.Namespace)
					r.Recorder.Event(imagePolicy, corev1.EventTypeNormal, "AutoRemediated",
						fmt.Sprintf("Auto-remediated deployment %s/%s to use latest digest", deployment.Namespace, deployment.Name))
					// Note: Don't update status here - let the next reconciliation cycle detect the actual change
				}
			} else {
				log.Info("Auto-remediation skipped",
					"deployment", deployment.Name,
					"namespace", deployment.Namespace,
					"reason", fmt.Sprintf("hasAutomation=%v, hasLatestDigest=%v", hasAutomation, hasLatestDigest))
			}
		}
	}

	// Update status
	imagePolicy.Status.MonitoredDeployments = deploymentStatuses
	imagePolicy.Status.TotalDeployments = int32(len(deployments))
	imagePolicy.Status.CompliantDeployments = compliantCount

	// Determine overall compliance status
	if len(deployments) == 0 {
		imagePolicy.Status.ComplianceStatus = securityv1.ComplianceStatusUnknown
		r.updateCondition(imagePolicy, securityv1.ConditionTypeReady, metav1.ConditionTrue,
			"NoDeployments", "No deployments found matching the policy")
	} else if compliantCount == int32(len(deployments)) {
		imagePolicy.Status.ComplianceStatus = securityv1.ComplianceStatusCompliant
		r.updateCondition(imagePolicy, securityv1.ConditionTypeReady, metav1.ConditionTrue,
			"AllCompliant", "All monitored deployments are compliant")
	} else {
		imagePolicy.Status.ComplianceStatus = securityv1.ComplianceStatusNonCompliant
		r.updateCondition(imagePolicy, securityv1.ConditionTypeReady, metav1.ConditionTrue,
			"NonCompliant", fmt.Sprintf("%d of %d deployments are non-compliant",
				int32(len(deployments))-compliantCount, len(deployments)))
	}

	// Update the status
	if err := r.Status().Update(ctx, imagePolicy); err != nil {
		log.Error(err, "Failed to update ImagePolicy status")
		return ctrl.Result{}, err
	}

	// Requeue after the check interval
	return ctrl.Result{RequeueAfter: time.Duration(checkInterval) * time.Second}, nil
}

// getLatestDigestFromDockerHub fetches the latest digest for a repository from DockerHub
func (r *ImagePolicyReconciler) getLatestDigestFromDockerHub(ctx context.Context, repository string) (string, error) {
	log := logf.FromContext(ctx)

	maxRetries := 3
	baseDelay := 5 * time.Second // Longer delay for rate limiting

	for attempt := 0; attempt < maxRetries; attempt++ {
		if attempt > 0 {
			delay := time.Duration(attempt) * baseDelay
			log.Info("Retrying DockerHub API request", "attempt", attempt+1, "delay", delay)
			time.Sleep(delay)
		}

		digest, err := r.fetchDigestFromDockerHub(ctx, repository)
		if err != nil {
			// If it's a rate limit error, retry
			if strings.Contains(err.Error(), "status 429") {
				log.Info("Rate limited by DockerHub, will retry", "attempt", attempt+1)
				continue
			}
			// For other errors, return immediately
			return "", err
		}

		log.Info("Successfully fetched latest digest", "repository", repository, "digest", digest)
		return digest, nil
	}

	return "", fmt.Errorf("failed to fetch digest after %d attempts due to rate limiting", maxRetries)
}

// fetchDigestFromDockerHub performs a single attempt to fetch the digest
func (r *ImagePolicyReconciler) fetchDigestFromDockerHub(ctx context.Context, repository string) (string, error) {
	// Get authentication token from DockerHub
	tokenURL := fmt.Sprintf("https://auth.docker.io/token?service=registry.docker.io&scope=repository:%s:pull", repository)

	tokenResp, err := http.Get(tokenURL)
	if err != nil {
		return "", fmt.Errorf("failed to get auth token: %w", err)
	}
	defer tokenResp.Body.Close()

	if tokenResp.StatusCode == 429 {
		return "", fmt.Errorf("DockerHub auth API returned status 429")
	}

	var tokenData DockerHubToken
	if err := json.NewDecoder(tokenResp.Body).Decode(&tokenData); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	// Get manifest for latest tag
	manifestURL := fmt.Sprintf("https://registry-1.docker.io/v2/%s/manifests/latest", repository)

	req, err := http.NewRequestWithContext(ctx, "GET", manifestURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create manifest request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+tokenData.Token)
	req.Header.Set("Accept", "application/vnd.docker.distribution.manifest.v2+json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to get manifest: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 429 {
		return "", fmt.Errorf("DockerHub registry API returned status 429")
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("DockerHub API returned status %d", resp.StatusCode)
	}

	// Get the digest from the Docker-Content-Digest header
	digest := resp.Header.Get("Docker-Content-Digest")
	if digest == "" {
		return "", fmt.Errorf("no digest found in response headers")
	}

	return digest, nil
}

// findDeploymentsToMonitor finds deployments that match the policy selectors
func (r *ImagePolicyReconciler) findDeploymentsToMonitor(ctx context.Context, policy *securityv1.ImagePolicy) ([]appsv1.Deployment, error) {
	var deployments []appsv1.Deployment

	// Get namespaces to search
	namespaces, err := r.getNamespacesToMonitor(ctx, policy)
	if err != nil {
		return nil, err
	}

	// Search deployments in each namespace
	for _, namespace := range namespaces {
		deploymentList := &appsv1.DeploymentList{}
		listOpts := []client.ListOption{
			client.InNamespace(namespace),
		}

		// Add deployment selector if specified
		if policy.Spec.DeploymentSelector != nil {
			selector, err := metav1.LabelSelectorAsSelector(policy.Spec.DeploymentSelector)
			if err != nil {
				return nil, fmt.Errorf("invalid deployment selector: %w", err)
			}
			listOpts = append(listOpts, client.MatchingLabelsSelector{Selector: selector})
		}

		if err := r.List(ctx, deploymentList, listOpts...); err != nil {
			return nil, fmt.Errorf("failed to list deployments in namespace %s: %w", namespace, err)
		}

		// Filter deployments that use images from the monitored repository
		for _, deployment := range deploymentList.Items {
			if r.deploymentUsesRepository(deployment, policy.Spec.Repository) {
				deployments = append(deployments, deployment)
			}
		}
	}

	return deployments, nil
}

// getNamespacesToMonitor returns the list of namespaces to monitor based on the policy
func (r *ImagePolicyReconciler) getNamespacesToMonitor(ctx context.Context, policy *securityv1.ImagePolicy) ([]string, error) {
	if policy.Spec.NamespaceSelector == nil {
		// Monitor all namespaces
		namespaceList := &corev1.NamespaceList{}
		if err := r.List(ctx, namespaceList); err != nil {
			return nil, fmt.Errorf("failed to list namespaces: %w", err)
		}

		var namespaces []string
		for _, ns := range namespaceList.Items {
			namespaces = append(namespaces, ns.Name)
		}
		return namespaces, nil
	}

	// Use selector to find namespaces
	selector, err := metav1.LabelSelectorAsSelector(policy.Spec.NamespaceSelector)
	if err != nil {
		return nil, fmt.Errorf("invalid namespace selector: %w", err)
	}

	namespaceList := &corev1.NamespaceList{}
	if err := r.List(ctx, namespaceList, client.MatchingLabelsSelector{Selector: selector}); err != nil {
		return nil, fmt.Errorf("failed to list namespaces with selector: %w", err)
	}

	var namespaces []string
	for _, ns := range namespaceList.Items {
		namespaces = append(namespaces, ns.Name)
	}
	return namespaces, nil
}

// deploymentUsesRepository checks if a deployment uses images from the specified repository
func (r *ImagePolicyReconciler) deploymentUsesRepository(deployment appsv1.Deployment, repository string) bool {
	for _, container := range deployment.Spec.Template.Spec.Containers {
		if strings.HasPrefix(container.Image, repository) || strings.HasPrefix(container.Image, "docker.io/"+repository) {
			return true
		}
	}
	return false
}

// analyzeDeploymentCompliance analyzes if a deployment is compliant with the policy
func (r *ImagePolicyReconciler) analyzeDeploymentCompliance(ctx context.Context, deployment appsv1.Deployment, repository, latestDigest string, enforceLatest bool, attestationPolicy *securityv1.AttestationPolicy) securityv1.DeploymentStatus {
	log := logf.FromContext(ctx)
	now := metav1.Now()
	status := securityv1.DeploymentStatus{
		Name:        deployment.Name,
		Namespace:   deployment.Namespace,
		IsCompliant: true,
		LastUpdated: &now,
	}

	// Find the container using our repository
	for _, container := range deployment.Spec.Template.Spec.Containers {
		if strings.HasPrefix(container.Image, repository) || strings.HasPrefix(container.Image, "docker.io/"+repository) {
			// Extract digest from image reference
			if strings.Contains(container.Image, "@sha256:") {
				parts := strings.Split(container.Image, "@")
				if len(parts) == 2 {
					status.CurrentDigest = parts[1]
				}

				if enforceLatest {
					if latestDigest == "" {
						// Can't determine compliance without latest digest - mark as unknown/error
						log.Info("Cannot determine compliance - latest digest unavailable",
							"deployment", deployment.Name,
							"namespace", deployment.Namespace,
							"currentDigest", status.CurrentDigest)
						status.IsCompliant = false // Conservative: assume non-compliant when we can't verify
					} else if status.CurrentDigest != latestDigest {
						log.Info("Digest mismatch detected",
							"deployment", deployment.Name,
							"namespace", deployment.Namespace,
							"currentDigest", status.CurrentDigest,
							"latestDigest", latestDigest)
						status.IsCompliant = false
					} else {
						log.Info("Digest match - compliant",
							"deployment", deployment.Name,
							"namespace", deployment.Namespace,
							"currentDigest", status.CurrentDigest,
							"latestDigest", latestDigest)
						status.IsCompliant = true
					}
				}
			} else {
				// Image uses tag, not digest - this is non-compliant if enforcing digests
				status.CurrentDigest = "tag-based"
				if enforceLatest {
					status.IsCompliant = false
				}
			}
			break
		}
	}

	// Verify attestations if policy requires it
	if attestationPolicy != nil && attestationPolicy.RequireAttestation != nil && *attestationPolicy.RequireAttestation {
		var attestationResult *rekor.AttestationResult

		// Check if we have a valid digest for attestation verification
		if status.CurrentDigest == "tag-based" || status.CurrentDigest == "" {
			// Tag-based images cannot be verified for attestations
			attestationResult = &rekor.AttestationResult{
				Verified: false,
				Error:    "Cannot verify attestations for tag-based images - digest required",
			}
		} else {
			// Verify attestation for digest-based images
			attestationResult = r.verifyAttestation(ctx, status.CurrentDigest, attestationPolicy)
		}

		// Update status with attestation information
		hasValidAttestation := attestationResult.Verified
		status.HasValidAttestation = &hasValidAttestation

		if attestationResult != nil {
			status.AttestationDetails = &securityv1.AttestationDetails{
				Verified:        attestationResult.Verified,
				AttestationType: attestationResult.AttestationType,
				Issuer:          attestationResult.Issuer,
				LastChecked:     &now,
				Error:           attestationResult.Error,
			}

			if attestationResult.LogIndex > 0 {
				status.AttestationDetails.RekorLogIndex = &attestationResult.LogIndex
			}
		}

		// Mark as non-compliant if attestation verification fails
		if !attestationResult.Verified {
			log.Info("Attestation verification failed",
				"deployment", deployment.Name,
				"namespace", deployment.Namespace,
				"digest", status.CurrentDigest,
				"error", attestationResult.Error)
			status.IsCompliant = false
		}
	}

	return status
}

// verifyAttestation verifies that an image digest has valid attestations in Rekor
func (r *ImagePolicyReconciler) verifyAttestation(ctx context.Context, imageDigest string, policy *securityv1.AttestationPolicy) *rekor.AttestationResult {
	log := logf.FromContext(ctx)

	// Skip verification if no digest available
	if imageDigest == "" {
		return &rekor.AttestationResult{
			Verified: false,
			Error:    "no image digest available for verification",
		}
	}

	// Skip verification if Rekor client not available
	if r.RekorClient == nil {
		log.Info("Rekor client not available, skipping attestation verification")
		return &rekor.AttestationResult{
			Verified: false,
			Error:    "Rekor client not initialized",
		}
	}

	// Prepare policy parameters
	var allowedIssuers []string
	var requiredTypes []string

	if policy.AllowedIssuers != nil {
		allowedIssuers = policy.AllowedIssuers
	}

	if policy.RequiredTypes != nil {
		requiredTypes = policy.RequiredTypes
	}

	// Verify attestation via Rekor
	result, err := r.RekorClient.VerifyAttestation(ctx, imageDigest, allowedIssuers, requiredTypes)
	if err != nil {
		log.Error(err, "Failed to verify attestation via Rekor", "digest", imageDigest)
		return &rekor.AttestationResult{
			Verified: false,
			Error:    fmt.Sprintf("Rekor verification failed: %v", err),
		}
	}

	return result
}

// hasAutomationEnabled checks if a deployment has the automation:true label
func (r *ImagePolicyReconciler) hasAutomationEnabled(deployment appsv1.Deployment) bool {
	if deployment.Labels == nil {
		return false
	}
	automation, exists := deployment.Labels["automation"]
	return exists && automation == "true"
}

// remediateDeployment updates a deployment to use the latest compliant image digest
func (r *ImagePolicyReconciler) remediateDeployment(ctx context.Context, deployment appsv1.Deployment, repository, latestDigest string) error {
	// Create a copy of the deployment for updating
	updatedDeployment := deployment.DeepCopy()

	// Find and update containers using the monitored repository
	updated := false
	for i, container := range updatedDeployment.Spec.Template.Spec.Containers {
		if strings.HasPrefix(container.Image, repository) || strings.HasPrefix(container.Image, "docker.io/"+repository) {
			// Extract repository name without registry prefix
			repoName := repository
			if strings.HasPrefix(container.Image, "docker.io/") {
				repoName = "docker.io/" + repository
			}

			// Update to use digest-based image reference
			newImage := repoName + "@" + latestDigest
			updatedDeployment.Spec.Template.Spec.Containers[i].Image = newImage
			updated = true
		}
	}

	if !updated {
		return fmt.Errorf("no containers found using repository %s", repository)
	}

	// Update the deployment
	if err := r.Update(ctx, updatedDeployment); err != nil {
		return fmt.Errorf("failed to update deployment: %w", err)
	}

	return nil
}

// updateCondition updates or adds a condition to the ImagePolicy status
func (r *ImagePolicyReconciler) updateCondition(policy *securityv1.ImagePolicy, conditionType string, status metav1.ConditionStatus, reason, message string) {
	now := metav1.Now()
	condition := metav1.Condition{
		Type:               conditionType,
		Status:             status,
		LastTransitionTime: now,
		Reason:             reason,
		Message:            message,
	}

	// Find existing condition
	for i, existingCondition := range policy.Status.Conditions {
		if existingCondition.Type == conditionType {
			// Update existing condition
			if existingCondition.Status != status {
				condition.LastTransitionTime = now
			} else {
				condition.LastTransitionTime = existingCondition.LastTransitionTime
			}
			policy.Status.Conditions[i] = condition
			return
		}
	}

	// Add new condition
	policy.Status.Conditions = append(policy.Status.Conditions, condition)
}

// SetupWithManager sets up the controller with the Manager.
func (r *ImagePolicyReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&securityv1.ImagePolicy{}).
		Owns(&appsv1.Deployment{}).
		Named("imagepolicy").
		Complete(r)
}
