import React from 'react'
import posed from 'react-pose'
const config = {
  visible: { opacity: 1 },
  hidden: { opacity: 0 },
}
const Box = posed.div(config)

export default class extends React.Component {
  state = {
    commentsShown: false,
  }
  render() {
    return (
      <>
        <Box pose={this.state.commentsShown ? 'hidden' : 'visible'}>
          <button
            className="button  db center shadow-fancy bn pa3 pv2 grow pointer"
            onClick={() =>
              this.setState(({ commentsShown }) => ({
                commentsShown: !commentsShown,
              }))
            }
          >
            Show comments
          </button>
        </Box>
        <Box pose={this.state.commentsShown ? 'visible' : 'hidden'}>
          <form
            method="POST"
            action="https://api.staticman.net/v2/entry/danbruder/blog/master/comments"
          >
            <input
              name="options[redirect]"
              type="hidden"
              value={this.props.redirect}
            />
            <input name="options[slug]" type="hidden" value="{{ page.slug }}" />
            <label>Name</label>
            <input name="fields[name]" type="text" />
            <label>Email</label>
            <input name="fields[email]" type="email" />
            <label>Comment</label>
            <textarea name="fields[message]" />

            <button type="submit">Go!</button>
          </form>
        </Box>
      </>
    )
  }
}
