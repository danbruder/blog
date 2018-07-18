import React from 'react'
import Img from 'gatsby-image'
import { Link } from 'gatsby'
import { get } from 'lodash'
import { Home } from 'react-feather'

import Layout from '../components/layout'
import { Calendar, Clock } from 'react-feather'

const BlogPage = ({ data }) => (
  <Layout>
    <div className="bg-light-gray">
      <div className="mw7 center w-100 pa3 pa5-ns ">
        <span className="fw5 ttu primary pr2">
          {get(data, 'blog.category.title', '')}
        </span>
        <h1 className="bb b--black-10 mv1 pb2 lh-title">{data.blog.title}</h1>
        <div className="pv2 ma0 gray flex items-center">
          <Calendar />
          <span className="fw3  mono ml2 mr4 ">
            {get(data, 'blog.date', '')}
          </span>
          <Clock />
          <span className="fw3 mono ml2 ">
            {get(data, 'blog.body.childMarkdownRemark.timeToRead', '')} minute
          </span>
        </div>
        <div
          className="lh-copy"
          dangerouslySetInnerHTML={{
            __html: get(data, 'blog.body.childMarkdownRemark.html', ''),
          }}
        />
      </div>
    </div>
  </Layout>
)

export default BlogPage

export const pageQuery = graphql`
  query BlogQuery($slug: String) {
    blog: contentfulPost(slug: { eq: $slug }) {
      title
      date(formatString: "MMMM, D YYYY")
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
