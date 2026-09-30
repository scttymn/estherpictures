package models

import (
	"regexp"
	"strings"
	"unicode/utf8"
)

// The roles: an admin also manages the users and the history.
const (
	Admin  = "admin"
	Editor = "editor"
)

// IsAdmin reports whether the user manages the users and the history.
func (u GetUserRow) IsAdmin() bool { return u.Role == Admin }

// MustChange reports whether the user signed in with a temporary password
// and has yet to choose their own.
func (u GetUserRow) MustChange() bool { return u.MustChangePassword != 0 }

var emailFormat = regexp.MustCompile(`^[^@,;\s]+@[^@,;\s]+$`)

// EmailErrors are what's wrong with an email address.
func EmailErrors(email string) []string {
	switch email = strings.TrimSpace(email); {
	case email == "":
		return []string{"Email can't be blank"}
	case !emailFormat.MatchString(email):
		return []string{"Email must have the @ sign and no spaces"}
	case len(email) > 160:
		return []string{"Email should be at most 160 characters"}
	}
	return nil
}

// PasswordErrors are what's wrong with a password someone chose: at least
// 7 characters and at most 72 bytes (bcrypt's limit), with an upper case
// letter and a digit, typed the same twice.
func PasswordErrors(password, confirmation string) []string {
	var errs []string
	switch {
	case password == "":
		return []string{"Password can't be blank"}
	case utf8.RuneCountInString(password) < 7:
		errs = append(errs, "Password should be at least 7 characters")
	case len(password) > 72:
		errs = append(errs, "Password should be at most 72 bytes")
	}
	if !strings.ContainsAny(password, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") {
		errs = append(errs, "Password needs at least one upper case character")
	}
	if !strings.ContainsAny(password, "0123456789") {
		errs = append(errs, "Password needs at least one digit")
	}
	if password != confirmation {
		errs = append(errs, "Password confirmation does not match password")
	}
	return errs
}
