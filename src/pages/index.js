import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { blogRootPath } from '../config'
import { BookOpen } from 'react-feather'

import Layout from '../components/layout'
import BlogTeaser from '../components/BlogTeaser'

const IndexPage = ({ data }) => (
  <Layout>
    <div className="bg-gray-light  ">
      <div className="mw7 pa3 pa5-l center pv3 pv4-l ">
        <div className="mb5">
          <h1>Hi, I'm Dan</h1>
          <h2 className=" fw3 lh-copy">
            I’m a software developer that builds web applications that are easy
            to use, robust, and secure.
          </h2>
          <p className="f5 pb3">
            My primary tools are Elixir/Phoenix and ReactJS.
          </p>
          <Link
            className="dib link ba b--green green white ph4 b fw4 pv2"
            to="/contact"
          >
            Contact me
          </Link>
        </div>
        <div className="pb5">
          <h3 className="bb b--black-10 pb1">Recent Posts</h3>
          {get(data, 'posts.edges', []).map((edge, key) => (
            <BlogTeaser data={edge} key={key} />
          ))}
          <Link className="flex items-center" to="/blog/page/1">
            <small>Next page</small>
          </Link>
        </div>
      </div>
    </div>
  </Layout>
)

export default IndexPage

export const pageQuery = graphql`
  fragment PostTeaserFragment on ContentfulPost {
    title
    date(formatString: "MMMM D, YYYY")
    slug
    category {
      title
    }
    body {
      childMarkdownRemark {
        timeToRead
      }
    }
  }

  query IndexQuery {
    posts: allContentfulPost(limit: 3, sort: { order: DESC, fields: [date] }) {
      edges {
        node {
          ...PostTeaserFragment
        }
      }
    }
  }
`
