package home

import "testing"

// Every kind of link an editor may paste plays: YouTube (every form of its
// links) and Vimeo embedded without controls and with sound, and a file
// as it is.
func TestPlayerFor(t *testing.T) {
	const (
		ytPlay = "https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w?autoplay=1&controls=0&disablekb=1&enablejsapi=1&fs=0&iv_load_policy=3&loop=1&modestbranding=1&mute=0&playlist=bFcu0Rn1d7w&playsinline=1&rel=0"
		ytCue  = "https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w?autoplay=0&controls=0&disablekb=1&enablejsapi=1&fs=0&iv_load_policy=3&loop=1&modestbranding=1&mute=0&playlist=bFcu0Rn1d7w&playsinline=1&rel=0"
		vimeo  = "https://player.vimeo.com/video/76979871?autoplay=1&byline=0&controls=0&loop=1&muted=0&portrait=0&title=0"
	)
	youtube := Player{Kind: "youtube", YouTubeID: "bFcu0Rn1d7w", Src: ytPlay, Cue: ytCue}
	for link, want := range map[string]Player{
		"https://www.youtube.com/watch?v=bFcu0Rn1d7w":           youtube,
		"https://youtu.be/bFcu0Rn1d7w?t=3":                      youtube,
		"https://www.youtube.com/watch?feature=x&v=bFcu0Rn1d7w": youtube,
		"https://www.youtube-nocookie.com/embed/bFcu0Rn1d7w":    youtube,
		"https://youtube.com/shorts/bFcu0Rn1d7w":                youtube,
		"https://vimeo.com/76979871":                            {Kind: "vimeo", Src: vimeo},
		"https://player.vimeo.com/video/76979871":               {Kind: "vimeo", Src: vimeo},
		"https://example.com/reel.mp4":                          {Kind: "file", Src: "https://example.com/reel.mp4", Cue: "https://example.com/reel.mp4"},
		"":                                                      {Kind: "none"},
	} {
		if got := PlayerFor(link); got != want {
			t.Errorf("%q:\n got %+v\nwant %+v", link, got, want)
		}
	}
}
