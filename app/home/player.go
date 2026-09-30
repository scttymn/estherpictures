package home

import (
	"net/url"
	"regexp"
)

// Player is how a clip plays in the hero, for the filmstrip's data-*
// attributes: its kind ("youtube", "vimeo", "file" or "none"), its YouTube
// id (the page drives YouTube's sound through its player API), and its
// source muted and not (the embed without controls, or the file itself).
type Player struct {
	Kind, YouTubeID, Muted, Unmuted string
}

// PlayerFor reads whatever reel link an editor pasted: a YouTube watch,
// share, embed or shorts link, a Vimeo link, or a video file's address.
func PlayerFor(videoURL string) Player {
	if videoURL == "" {
		return Player{Kind: "none"}
	}
	if id := youTubeID(videoURL); id != "" {
		return Player{Kind: "youtube", YouTubeID: id, Muted: YouTubeEmbed(id, true), Unmuted: YouTubeEmbed(id, false)}
	}
	if m := vimeoLink.FindStringSubmatch(videoURL); m != nil {
		return Player{Kind: "vimeo", Muted: VimeoEmbed(m[1], true), Unmuted: VimeoEmbed(m[1], false)}
	}
	return Player{Kind: "file", Muted: videoURL, Unmuted: videoURL}
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

// YouTubeEmbed is a YouTube video playing on a loop without controls,
// muted or not, with the player API on (enablejsapi), so the page can
// unmute it in answer to a tap: iOS plays sound only then.
func YouTubeEmbed(id string, muted bool) string {
	q := url.Values{"autoplay": {"1"}, "mute": {flag(muted)}, "loop": {"1"}, "playlist": {id}, "controls": {"0"},
		"modestbranding": {"1"}, "rel": {"0"}, "playsinline": {"1"}, "iv_load_policy": {"3"}, "disablekb": {"1"},
		"fs": {"0"}, "enablejsapi": {"1"}}
	return "https://www.youtube-nocookie.com/embed/" + id + "?" + q.Encode()
}

// VimeoEmbed is a Vimeo video playing on a loop without controls, muted or
// not. Muted, it's Vimeo's background mode, the cleanest start, which
// can't have sound.
func VimeoEmbed(id string, muted bool) string {
	q := url.Values{"autoplay": {"1"}, "loop": {"1"}, "muted": {flag(muted)}, "controls": {"0"}, "title": {"0"},
		"byline": {"0"}, "portrait": {"0"}}
	if muted {
		q.Set("background", "1")
	}
	return "https://player.vimeo.com/video/" + id + "?" + q.Encode()
}

func flag(b bool) string {
	if b {
		return "1"
	}
	return "0"
}
