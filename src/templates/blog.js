import React from 'react'
import Img from 'gatsby-image'
import { Link } from 'gatsby'
import { get } from 'lodash'
import { Home } from 'react-feather'

import Layout from '../components/layout'
import { Calendar, Clock } from 'react-feather'

const BlogPage = ({ data }) => (
  <Layout>
    <div className="bg-gray-light">
      <div className="mw7 center w-100 pa3 pv4-ns ph5-l ">
        <span className="fw5 ttu primary pr2">
          {get(data, 'blog.category.title', '')}
        </span>
        <h1 className="bb b--black-10 mv1 pb2 lh-title">{data.blog.title}</h1>
        <div className="f7 pv2 ma0 gray flex items-center">
          <Calendar className="h1 w1" />
          <span className="fw3  mono ml2 mr3 ">
            {get(data, 'blog.date', '')}
          </span>
          <Clock className="h1 w1" />
          <span className="fw3 mono ml2 ">
            {get(data, 'blog.body.childMarkdownRemark.timeToRead', '')} minute
          </span>
        </div>
        <div
          className="lh-copy body"
          dangerouslySetInnerHTML={{
            __html: get(data, 'blog.body.childMarkdownRemark.html', ''),
          }}
        />

        <SubscribeForm/>
      </div>
    </div>
  </Layout>
)

const SubscribeForm = () => (
    <form
    action="https://buttondown.email/api/emails/embed-subscribe/danbruder"
    method="post"
    target="popupwindow"
    onsubmit="window.open('https://buttondown.email/danbruder', 'popupwindow')"
    class="pa3 bg-white mv3 card"
>
        <div class="pa0">
            <p class="pa0 ma0">Subscribe</p>
        </div>
        <div class="f6 gray">
            <label for="bd-email block f5 light-gray">No spam, just software engineering tips</label>
        </div>
        <div class="mt2">
            <input class="o--gray" type="email" name="email" id="bd-email" />
            <input type="submit" value="Subscribe" />
        </div>
    </form>
)

const formatShareLink = data => {
  let slug = get(data, 'blog.slug')
  let url = `https://danbruder.com/blog/${slug}`
  let text = get(data, 'blog.title')
  let via = `danbruder`
  return `https://twitter.com/intent/tweet?url=${url}&text=${text}&via=${via}`
}

export default BlogPage

export const pageQuery = graphql`
  query BlogQuery($slug: String) {
    blog: contentfulPost(slug: { eq: $slug }) {
      title
      slug
      date(formatString: "MMMM D, YYYY")
      category {
        title
      }
      body {
        childMarkdownRemark {
          html
          timeToRead
        }
      }
    }
  }
`
