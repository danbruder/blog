import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { blogRootPath } from '../config'

import Layout from '../components/layout'
import BlogTeaser from '../components/BlogTeaser'

const IndexPage = ({ data }) => (
  <Layout>
    <div className="bg-light-gray  ">
      <div className="mw7 pa3 pa5-l center pv3 pv4-l bg-light-gray ">
        <div className="mb5">
          <h1>Hi, I'm Dan</h1>
          <h2 className=" fw3 lh-copy">
            I’m a software developer that builds web applications that are easy
            to use, robust, and secure.
          </h2>
          <p className="f5 pb3">
            My primary tools are Elixir/Phoenix and ReactJS.
          </p>
          <a
            className="dib link bg-green white ph4 b  fw4 pv2"
            href="mailto:hello@danbruder.com"
          >
            Contact me
          </a>
        </div>
        <div className="">
          <h3 className="bb b--black-10 pb1">Blog</h3>
          {get(data, 'posts.edges', []).map((edge, key) => (
            <BlogTeaser data={edge} key={key} />
          ))}
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
    summary {
      childMarkdownRemark {
        html
      }
    }
  }

  query IndexQuery {
    posts: allContentfulPost(sort: { order: DESC, fields: [date] }) {
      edges {
        node {
          ...PostTeaserFragment
        }
      }
    }
  }
`
