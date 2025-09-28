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

package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Compliance status constants
const (
	ComplianceStatusCompliant    = "Compliant"
	ComplianceStatusNonCompliant = "NonCompliant"
	ComplianceStatusUnknown      = "Unknown"
	ComplianceStatusError        = "Error"
)

// Condition types
const (
	ConditionTypeReady       = "Ready"
	ConditionTypeProgressing = "Progressing"
	ConditionTypeDegraded    = "Degraded"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// ImagePolicySpec defines the desired state of ImagePolicy
type ImagePolicySpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Repository specifies the DockerHub repository to monitor (e.g., "jonlimpw/demo-app")
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Pattern=`^[a-z0-9]+(?:[._-][a-z0-9]+)*\/[a-z0-9]+(?:[._-][a-z0-9]+)*$`
	Repository string `json:"repository"`

	// NamespaceSelector specifies which namespaces to monitor for deployments
	// If empty, monitors all namespaces
	// +optional
	NamespaceSelector *metav1.LabelSelector `json:"namespaceSelector,omitempty"`

	// DeploymentSelector specifies which deployments to monitor within selected namespaces
	// If empty, monitors all deployments
	// +optional
	DeploymentSelector *metav1.LabelSelector `json:"deploymentSelector,omitempty"`

	// CheckIntervalSeconds defines how often to check for new image digests (default: 60)
	// +kubebuilder:validation:Minimum=10
	// +kubebuilder:validation:Maximum=3600
	// +kubebuilder:default=60
	// +optional
	CheckIntervalSeconds *int32 `json:"checkIntervalSeconds,omitempty"`

	// EnforceLatestDigest when true, marks deployments as non-compliant if not using latest digest
	// +kubebuilder:default=true
	// +optional
	EnforceLatestDigest *bool `json:"enforceLatestDigest,omitempty"`

	// AttestationPolicy defines requirements for cryptographic attestations
	// +optional
	AttestationPolicy *AttestationPolicy `json:"attestationPolicy,omitempty"`
}

// AttestationPolicy defines the attestation verification requirements
type AttestationPolicy struct {
	// RequireAttestation when true, marks deployments as non-compliant if they lack valid attestations
	// +kubebuilder:default=false
	// +optional
	RequireAttestation *bool `json:"requireAttestation,omitempty"`

	// AllowedIssuers specifies the allowed OIDC issuers for attestation certificates
	// +optional
	AllowedIssuers []string `json:"allowedIssuers,omitempty"`

	// RequiredTypes specifies the required attestation types (e.g., "slsaprovenance")
	// +optional
	RequiredTypes []string `json:"requiredTypes,omitempty"`

	// MaxAge specifies the maximum age of attestations to accept (e.g., "24h")
	// +optional
	MaxAge *string `json:"maxAge,omitempty"`
}

// ImagePolicyStatus defines the observed state of ImagePolicy.
type ImagePolicyStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// LatestDigest contains the most recent digest found for the monitored repository
	// +optional
	LatestDigest string `json:"latestDigest,omitempty"`

	// LastChecked timestamp of the last successful check against DockerHub
	// +optional
	LastChecked *metav1.Time `json:"lastChecked,omitempty"`

	// ComplianceStatus summarizes the overall compliance state
	// +kubebuilder:validation:Enum=Compliant;NonCompliant;Unknown;Error
	// +optional
	ComplianceStatus string `json:"complianceStatus,omitempty"`

	// MonitoredDeployments tracks deployments being monitored by this policy
	// +optional
	MonitoredDeployments []DeploymentStatus `json:"monitoredDeployments,omitempty"`

	// TotalDeployments is the count of deployments being monitored
	// +optional
	TotalDeployments int32 `json:"totalDeployments,omitempty"`

	// CompliantDeployments is the count of deployments using the latest digest
	// +optional
	CompliantDeployments int32 `json:"compliantDeployments,omitempty"`

	// conditions represent the current state of the ImagePolicy resource.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// DeploymentStatus tracks the compliance status of a specific deployment
type DeploymentStatus struct {
	// Name of the deployment
	Name string `json:"name"`

	// Namespace of the deployment
	Namespace string `json:"namespace"`

	// CurrentDigest is the digest currently used by the deployment
	CurrentDigest string `json:"currentDigest"`

	// IsCompliant indicates if the deployment is using the latest digest
	IsCompliant bool `json:"isCompliant"`

	// HasValidAttestation indicates if the deployment's image has valid attestations
	// +optional
	HasValidAttestation *bool `json:"hasValidAttestation,omitempty"`

	// AttestationDetails provides information about the attestation verification
	// +optional
	AttestationDetails *AttestationDetails `json:"attestationDetails,omitempty"`

	// LastUpdated timestamp when this status was last updated
	LastUpdated *metav1.Time `json:"lastUpdated,omitempty"`
}

// AttestationDetails provides information about attestation verification results
type AttestationDetails struct {
	// Verified indicates if the attestation was successfully verified
	Verified bool `json:"verified"`

	// AttestationType is the type of attestation found (e.g., "slsaprovenance")
	// +optional
	AttestationType string `json:"attestationType,omitempty"`

	// Issuer is the OIDC issuer of the attestation certificate
	// +optional
	Issuer string `json:"issuer,omitempty"`

	// RekorLogIndex is the Rekor transparency log index for this attestation
	// +optional
	RekorLogIndex *int64 `json:"rekorLogIndex,omitempty"`

	// LastChecked timestamp when attestation was last verified
	// +optional
	LastChecked *metav1.Time `json:"lastChecked,omitempty"`

	// Error message if attestation verification failed
	// +optional
	Error string `json:"error,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Namespaced,categories=security
// +kubebuilder:printcolumn:name="Repository",type="string",JSONPath=".spec.repository"
// +kubebuilder:printcolumn:name="Compliance",type="string",JSONPath=".status.complianceStatus"
// +kubebuilder:printcolumn:name="Total",type="integer",JSONPath=".status.totalDeployments"
// +kubebuilder:printcolumn:name="Compliant",type="integer",JSONPath=".status.compliantDeployments"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// ImagePolicy is the Schema for the imagepolicies API
type ImagePolicy struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty,omitzero"`

	// spec defines the desired state of ImagePolicy
	// +required
	Spec ImagePolicySpec `json:"spec"`

	// status defines the observed state of ImagePolicy
	// +optional
	Status ImagePolicyStatus `json:"status,omitempty,omitzero"`
}

// +kubebuilder:object:root=true

// ImagePolicyList contains a list of ImagePolicy
type ImagePolicyList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ImagePolicy `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ImagePolicy{}, &ImagePolicyList{})
}
