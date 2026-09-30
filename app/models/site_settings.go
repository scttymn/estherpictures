package models

// Errors are what's wrong with the site copy's form.
func (s SiteSetting) Errors() []string { return required("Collective name", s.CollectiveName) }
