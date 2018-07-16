import React from 'react'
import Img from 'gatsby-image'
import { get } from 'lodash'

import Layout from '../components/layout'

import Meta from '../components/meta'
const BlogPage = ({ data }) => (
  <Layout>
    <Meta
      title={get(data, 'blog.title', null)}
      url={`/blog/${get(data, 'blog.slug', '')}`}
    />
    <div className="bg-light-gray">
      <div className="mw9 center w-100 pa5-ns ">
        <div className="cf pa3 pa0-ns">
          <div className="fn fl-l w-70-l">
            <i className="db mv3 gray">
              {get(data, 'blog.createdAt', '')} by{' '}
              {get(data, 'blog.author.name', '')}
            </i>
            <h1 className="f2 lh-title fw9 mb3 mt0 pt3 bt bw1">
              {get(data, 'blog.title', '')}
            </h1>
            <h2 className="f3 mid-gray lh-title">
              {get(data, 'blog.summary', '')}
            </h2>
            <div
              className="blog-body f5 lh-copy  mt0-l"
              dangerouslySetInnerHTML={{
                __html: get(data, 'blog.body.childMarkdownRemark.html', ''),
              }}
            />
          </div>
          <div className="pa2 pa3-l measure  fn fl-l w-100 w-100 w-30-l w-100-m pr4-l mt4">
            <div className=" ml5-l mt0 pt0">
              <div className=" tl">
                <Img
                  className="br-100 h3 w3 dib"
                  sizes={get(data, 'blog.author.avatar.sizes', {})}
                />
                <h1 className="f5 gray i fw3">
                  By: {get(data, 'blog.author.name', '')}
                </h1>
                <hr className=" bb bw1 b--black-10" />
              </div>
              <p
                className="lh-copy  center f6 black-70"
                dangerouslySetInnerHTML={{
                  __html: get(
                    data,
                    'blog.author.bio.childMarkdownRemark.html',
                    ''
                  ),
                }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </Layout>
)

export default BlogPage

export const pageQuery = graphql`
  query BlogQuery($slug: String) {
    blog: contentfulPost(slug: { eq: $slug }) {
      title
      summary
      id
      slug
      createdAt(formatString: "M/D/YY")
      author {
        name
        bio {
          childMarkdownRemark {
            html
          }
        }
        avatar {
          sizes(maxWidth: 200) {
            ...GatsbyContentfulSizes_tracedSVG
          }
        }
      }
      body {
        childMarkdownRemark {
          html
          excerpt
        }
      }
    }
  }
`
