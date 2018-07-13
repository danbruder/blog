import React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { Link } from 'gatsby'

import Layout from '../components/layout'

const BlogTeaser = ({ data }) => (
  <div className="br3 grow shadow-hover ma3 bg-white w-100 mw5-ns">
    <Link className="link black" to={`/blog/${data.node.slug}`}>
      <div className="pa3">
        <label className="tracked ttu gray fw2">Post</label>
        <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
        <p>{get(data, 'node.summary', '')}</p>
      </div>
    </Link>
  </div>
)

const BlogPage = ({ data }) => (
  <Layout>
    <div className="mw9 center w-100 pa3 pa5-ns bg-light-gray">
      <h1 className="f1 lh-title tc">Blog</h1>
      <h2 className="f3 fw3 tc">
        We write here as we encounter and solve technical challenges.
      </h2>
      <div className="mt5-ns justify-center flex flex-wrap">
        {get(data, 'blogs.edges', []).map((edge, key) => (
          <BlogTeaser key={key} data={edge} />
        ))}
      </div>
    </div>
  </Layout>
)

export default BlogPage

export const pageQuery = graphql`
  query BlogPageQuery {
    blogs: allContentfulPost(sort: { order: DESC, fields: [createdAt] }) {
      edges {
        node {
          slug
          title
          summary
          createdAt(formatString: "M/D/YY")
          author {
            name
            avatar {
              sizes(maxWidth: 200) {
                ...GatsbyContentfulSizes_tracedSVG
              }
            }
          }
        }
      }
    }
  }
`
