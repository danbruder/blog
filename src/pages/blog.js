import React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { Link } from 'gatsby'
import Meta from '../components/meta'

import Layout from '../components/layout'

const BlogTeaser = ({ data }) => (
  <div className=" w-33-l     ">
    <Link className="black link pr3 db" to={`/blog/${data.node.slug}`}>
      <div className="pv4 measure bt b--black-90  ">
        <h2 className="f3 ma0 ">{get(data, 'node.title', '')}</h2>
        <p className="mt1 lh-copy">{get(data, 'node.summary', '')}</p>
        <div className="flex items-center pt0">
          <Img
            className="br-100 h2 w2 dib ba b--black-05 "
            sizes={get(data, 'node.author.avatar.sizes', {})}
          />
          <label className="i  ml2 ">
            {get(data, 'node.createdAt', '')} by{' '}
            {get(data, 'node.author.name', '')}
          </label>
        </div>
      </div>
    </Link>
  </div>
)

const BlogPage = ({ data }) => (
  <Layout>
    <Meta
      title="Blog"
      description="We write here as we encounter and solve technical challenges."
      url="blog"
    />
    <div className="bg-light-gray">
      <div className="mw9 center w-100 pa3 pa5-ns bg-light-gray">
        <h1 className="f2 lh-title ">Blog</h1>
        <h2 className="f4 i  fw3 ">
          We write here as we encounter and solve technical challenges.
        </h2>
        <div className="flex flex-wrap">
          {get(data, 'blogs.edges', []).map((edge, key) => (
            <BlogTeaser key={key} data={edge} />
          ))}
        </div>
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
