package home

import "testing"

// Every kind of link an editor may paste plays as the Phoenix app played
// it: the same embed addresses, character for character (its output, taken
// from EstherPicturesWeb.PageHTML.clip_player).
func TestPlayerFor(t *testing.T) {
	const (
		ytMuted   = "https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w?autoplay=1&controls=0&disablekb=1&enablejsapi=1&fs=0&iv_load_policy=3&loop=1&modestbranding=1&mute=1&playlist=bFcu0Rn1d7w&playsinline=1&rel=0"
		ytUnmuted = "https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w?autoplay=1&controls=0&disablekb=1&enablejsapi=1&fs=0&iv_load_policy=3&loop=1&modestbranding=1&mute=0&playlist=bFcu0Rn1d7w&playsinline=1&rel=0"
		vMuted    = "https://player.vimeo.com/video/76979871?autoplay=1&background=1&byline=0&controls=0&loop=1&muted=1&portrait=0&title=0"
		vUnmuted  = "https://player.vimeo.com/video/76979871?autoplay=1&byline=0&controls=0&loop=1&muted=0&portrait=0&title=0"
	)
	youtube := Player{Kind: "youtube", YouTubeID: "bFcu0Rn1d7w", Muted: ytMuted, Unmuted: ytUnmuted}
	vimeo := Player{Kind: "vimeo", Muted: vMuted, Unmuted: vUnmuted}
	for link, want := range map[string]Player{
		"https://www.youtube.com/watch?v=bFcu0Rn1d7w":           youtube,
		"https://youtu.be/bFcu0Rn1d7w?t=3":                      youtube,
		"https://www.youtube.com/watch?feature=x&v=bFcu0Rn1d7w": youtube,
		"https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w":    youtube,
		"https://youtube.com/shorts/bFcu0Rn1d7w":                youtube,
		"https://vimeo.com/76979871":                            vimeo,
		"https://player.vimeo.com/video/76979871":               vimeo,
		"https://example.com/reel.mp4":                          {Kind: "file", Muted: "https://example.com/reel.mp4", Unmuted: "https://example.com/reel.mp4"},
		"":                                                      {Kind: "none"},
	} {
		if got := PlayerFor(link); got != want {
			t.Errorf("%q:\n got %+v\nwant %+v", link, got, want)
		}
	}
}
