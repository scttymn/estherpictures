// Package assets is the app's stylesheets, scripts, fonts and images,
// embedded in the binary and served under fingerprinted names (see gantry's
// assets package for the folder convention). public/ is served at the
// site's root, as Rails' public/: robots.txt, the favicon, and the error
// pages. js/vendor/ is the JavaScript packages `gantry importmap pin`
// downloaded.
package assets

import (
	"embed"
	"net/http"

	gantry "github.com/scttymn/gantry/assets"
)

//go:embed css fonts js public all:built
var files embed.FS

// All is every asset, digested once at start.
var All = gantry.MustNew(files)

// Site is the public page's stylesheets, with the faces on its first
// screen preloaded, so its text paints once in its font. Archivo is one
// file for every weight.
var Site = All.Styles("fonts.css", "site.css").Preload(
	gantry.Face{Family: "Archivo"},
	gantry.Face{Family: "Space Mono"},
	gantry.Face{Family: "Space Mono", Weight: 700},
)

// Admin is the admin's stylesheet, and its sign-in pages'.
var Admin = All.Styles("admin.css")

// ImportMap is the admin's JavaScript by name (Rails' config/importmap.rb):
// js/application.js, the Stimulus controllers in js/controllers, and every
// package in js/vendor ("@hotwired--turbo.js" is "@hotwired/turbo"). The
// public page has no need of them: its one script is site.js.
var ImportMap = All.ImportMap(
	gantry.Pin("application", "application.js"),
	gantry.PinAll("controllers"),
	gantry.PinVendor("vendor"),
)

// Path is an asset's URL: "/assets/site-1a2b3c4d.js".
func Path(name string) string { return All.Path(name) }

// Routes mounts /assets/ and the root files.
func Routes(mount func(pattern string, h http.Handler)) { All.Routes(mount) }
