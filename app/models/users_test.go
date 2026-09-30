package models

import (
	"strings"
	"testing"
)

// The Phoenix app's password rules: 7 characters to 72 bytes, an upper
// case letter and a digit, typed twice the same.
func TestPasswordErrors(t *testing.T) {
	for password, want := range map[string]string{
		"Abcdef1":                      "",
		"":                             "can't be blank",
		"Abc1":                         "at least 7 characters",
		"abcdefg1":                     "upper case",
		"Abcdefgh":                     "digit",
		"A1" + strings.Repeat("é", 36): "at most 72 bytes",
	} {
		errs := strings.Join(PasswordErrors(password, password), "; ")
		if (want == "") != (errs == "") || !strings.Contains(errs, want) {
			t.Errorf("%q: %q, want %q", password, errs, want)
		}
	}
	if errs := PasswordErrors("Abcdef1", "Abcdef2"); len(errs) != 1 || !strings.Contains(errs[0], "does not match") {
		t.Errorf("a mismatch: %v", errs)
	}
}

func TestEmailErrors(t *testing.T) {
	for email, ok := range map[string]bool{"a@b.c": true, " a@b ": true, "": false, "a b@c.d": false, "a@b@c": false, "ab.c": false,
		strings.Repeat("a", 160) + "@b": false} {
		if got := len(EmailErrors(email)) == 0; got != ok {
			t.Errorf("%q: ok %v, want %v", email, got, ok)
		}
	}
}
