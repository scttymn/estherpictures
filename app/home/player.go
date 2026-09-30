package home

import (
	"net/url"
	"regexp"
)

// Player is how a clip plays in the hero, for the filmstrip's data-*
// attributes and the hero's first player. Nothing plays until a visitor
// taps: then it plays with sound.
type Player struct {
	Kind      string // "youtube", "vimeo", "file" or "none"
	YouTubeID string // the page drives YouTube through its player API
	// Src plays at once, with sound: what a tap loads when there's no player
	// ready (a Vimeo clip, another clip before YouTube's API is in).
	Src string
	// Cue is the first clip's player, loaded ahead and paused, so a tap can
	// start it at once: YouTube's (its API plays it inside the tap, which
	// iOS needs for sound), or the file. "" for Vimeo, which plays from Src.
	Cue string
}

// PlayerFor reads whatever reel link an editor pasted: a YouTube watch,
// share, embed or shorts link, a Vimeo link, or a video file's address.
func PlayerFor(videoURL string) Player {
	if videoURL == "" {
		return Player{Kind: "none"}
	}
	if id := youTubeID(videoURL); id != "" {
		return Player{Kind: "youtube", YouTubeID: id, Src: YouTubeEmbed(id, true), Cue: YouTubeEmbed(id, false)}
	}
	if m := vimeoLink.FindStringSubmatch(videoURL); m != nil {
		return Player{Kind: "vimeo", Src: VimeoEmbed(m[1])}
	}
	return Player{Kind: "file", Src: videoURL, Cue: videoURL}
}

var youTubeLinks = []*regexp.Regexp{
	regexp.MustCompile(`youtu\.be/([\w-]{11})`),
	regexp.MustCompile(`youtube(?:-nocookie)?\.com/watch\?(?:.*&)?v=([\w-]{11})`),
	regexp.MustCompile(`youtube(?:-nocookie)?\.com/embed/([\w-]{11})`),
	regexp.MustCompile(`youtube\.com/shorts/([\w-]{11})`),
}

var vimeoLink = regexp.MustCompile(`vimeo\.com/(?:video/)?(\d+)`)

func youTubeID(link string) string {
	for _, re := range youTubeLinks {
		if m := re.FindStringSubmatch(link); m != nil {
			return m[1]
		}
	}
	return ""
}

// YouTubeEmbed is a YouTube video on a loop, with sound and without
// controls, playing at once or loaded paused, with the player API on
// (enablejsapi) so the page can play and pause it.
func YouTubeEmbed(id string, autoplay bool) string {
	q := url.Values{"autoplay": {flag(autoplay)}, "mute": {"0"}, "loop": {"1"}, "playlist": {id}, "controls": {"0"},
		"modestbranding": {"1"}, "rel": {"0"}, "playsinline": {"1"}, "iv_load_policy": {"3"}, "disablekb": {"1"},
		"fs": {"0"}, "enablejsapi": {"1"}}
	return "https://www.youtube-nocookie.com/embed/" + id + "?" + q.Encode()
}

// VimeoEmbed is a Vimeo video playing at once on a loop, with sound and
// without controls; the page pauses and plays it by message (its player's
// postMessage API).
func VimeoEmbed(id string) string {
	q := url.Values{"autoplay": {"1"}, "loop": {"1"}, "muted": {"0"}, "controls": {"0"}, "title": {"0"},
		"byline": {"0"}, "portrait": {"0"}}
	return "https://player.vimeo.com/video/" + id + "?" + q.Encode()
}

func flag(b bool) string {
	if b {
		return "1"
	}
	return "0"
}
