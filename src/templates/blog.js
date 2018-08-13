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
        <small class=" w-100 db mt4">
          <a href={formatShareLink(data)}>Tweet this post</a>
        </small>
        {false && (
          <div className="mv4 pv3 bt b--black-10">
            <small class=" w-100 db ">
              Dan is a software developer that builds web applications that are
              easy to use, robust, and secure.
            </small>
          </div>
        )}
      </div>
    </div>
  </Layout>
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
