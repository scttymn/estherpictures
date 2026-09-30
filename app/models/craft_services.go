package models

// Errors are what's wrong with a service's form.
func (s CraftService) Errors() []string { return required("Title", s.Title) }
