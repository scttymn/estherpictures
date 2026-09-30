package admin

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/scttymn/gantry/images"
	"github.com/scttymn/gantry/storage"
)

// sniff tells a picture's type from its bytes.
var sniff = &images.Pipeline{}

// MaxImage is the largest image an editor may upload.
const MaxImage = 5 << 20

// images are the kinds an editor may upload, told by their bytes.
var imageTypes = map[string]bool{"image/jpeg": true, "image/png": true, "image/webp": true, "image/gif": true}

// Image is the image a form sent in field, if one was chosen, or what's
// wrong with it: what (e.g. "Thumbnail") names it in the message.
func (c Controller) Image(r *http.Request, field, what string) (f *storage.File, problem string) {
	file, ok := storage.FileFrom(r, field)
	if !ok {
		return nil, ""
	}
	if _, _, contentType, err := sniff.Dimensions(file.Data); err != nil || !imageTypes[contentType] {
		return nil, what + " must be a JPG, PNG, WebP, or GIF image."
	}
	if len(file.Data) > MaxImage {
		return nil, what + " must be 5 MB or smaller."
	}
	file.Filename = strings.TrimSpace(file.Filename)
	return &file, ""
}

// Position reads a form's position: blank is 0, as the column's default;
// ok is false for anything but a whole number.
func Position(v string) (n int64, ok bool) {
	v = strings.TrimSpace(v)
	if v == "" {
		return 0, true
	}
	n, err := strconv.ParseInt(v, 10, 64)
	return n, err == nil
}
