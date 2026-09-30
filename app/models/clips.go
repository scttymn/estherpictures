package models

// Errors are what's wrong with a clip's form.
func (c Clip) Errors() []string { return required("Title", c.Title) }
