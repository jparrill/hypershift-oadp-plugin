package validation

// Test scenario names follow: "When <action or context>, It Should <expected outcome>".

import (
	"testing"

	. "github.com/onsi/gomega"
	hyperv1 "github.com/openshift/hypershift/api/hypershift/v1beta1"
	"github.com/sirupsen/logrus"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestRestoreValidatePluginConfig(t *testing.T) {
	tests := []struct {
		name       string
		config     map[string]string
		wantMigr   bool
		expectError bool
	}{
		{
			name:   "When config is empty, It Should return default options without error",
			config: map[string]string{},
		},
		{
			name:     "When config has migration true, It Should set Migration to true",
			config:   map[string]string{"migration": "true"},
			wantMigr: true,
		},
		{
			name:   "When config has migration false, It Should leave Migration as false",
			config: map[string]string{"migration": "false"},
		},
		{
			name:   "When config has etcdBackupMethod, It Should accept it without error",
			config: map[string]string{"etcdBackupMethod": "etcdSnapshot"},
		},
		{
			name:   "When config has hoNamespace, It Should accept it without error",
			config: map[string]string{"hoNamespace": "my-hypershift"},
		},
		{
			name:   "When config has unknown key, It Should not return error",
			config: map[string]string{"unknownKey": "value"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			g := NewWithT(t)
			p := &RestorePluginValidator{
				Log:       logrus.New(),
				LogHeader: "test",
			}

			opts, err := p.ValidatePluginConfig(tt.config)
			if tt.expectError {
				g.Expect(err).To(HaveOccurred())
			} else {
				g.Expect(err).ToNot(HaveOccurred())
				g.Expect(opts.Migration).To(Equal(tt.wantMigr))
			}
		})
	}
}

func TestRestoreValidatePlatformConfig(t *testing.T) {
	tests := []struct {
		name         string
		platformType hyperv1.PlatformType
		wantErr      bool
		errSubstr    string
	}{
		{
			name:         "When ValidatePlatformConfig runs with AWS platform, It Should return no error",
			platformType: hyperv1.AWSPlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with Azure platform, It Should return no error",
			platformType: hyperv1.AzurePlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with IBMCloud platform, It Should return no error",
			platformType: hyperv1.IBMCloudPlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with Kubevirt platform, It Should return no error",
			platformType: hyperv1.KubevirtPlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with OpenStack platform, It Should return no error",
			platformType: hyperv1.OpenStackPlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with Agent platform, It Should return no error",
			platformType: hyperv1.AgentPlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with None platform, It Should return no error",
			platformType: hyperv1.NonePlatform,
		},
		{
			name:         "When ValidatePlatformConfig runs with unsupported platform, It Should return error",
			platformType: hyperv1.PlatformType("UnsupportedPlatform"),
			wantErr:      true,
			errSubstr:    "unsupported platform type",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			g := NewWithT(t)
			p := &RestorePluginValidator{
				Log:       logrus.New(),
				LogHeader: "test",
			}

			hcp := &hyperv1.HostedControlPlane{
				ObjectMeta: metav1.ObjectMeta{Name: "test-hcp", Namespace: "test-ns"},
				Spec: hyperv1.HostedControlPlaneSpec{
					Platform: hyperv1.PlatformSpec{Type: tt.platformType},
				},
			}

			err := p.ValidatePlatformConfig(hcp, map[string]string{})
			if tt.wantErr {
				g.Expect(err).To(HaveOccurred())
				g.Expect(err.Error()).To(ContainSubstring(tt.errSubstr))
			} else {
				g.Expect(err).ToNot(HaveOccurred())
			}
		})
	}
}
