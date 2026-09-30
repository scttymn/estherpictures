package models

import "strings"

// Errors are what's wrong with a member's form.
func (m EnsembleMember) Errors() []string { return required("Name", m.Name) }

// HasBio reports whether the member's row opens to show a bio.
func (m EnsembleMember) HasBio() bool { return strings.TrimSpace(m.Bio) != "" }
