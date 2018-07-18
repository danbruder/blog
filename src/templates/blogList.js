import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { blogRootPath } from '../config'

import Layout from '../components/layout'
import BlogTeaser from '../components/BlogTeaser'
import AuthorTeaser from '../components/AuthorTeaser'

const BlogListPage = ({ data, pageContext: { hasNextPage, nextPageLink } }) => (
  <Layout>
    <div className="bg-gray-light ">
      <div className="mw9 center w-100 pa3 pa5-ns flex">
        <div className="w-30">
          <AuthorTeaser />
        </div>
        <div className="bl b--black-10 w-70">
          {get(data, 'posts.edges', []).map((edge, key) => (
            <BlogTeaser data={edge} key={key} />
          ))}
          <div className="pa3 ph5-l">
            {hasNextPage && <Link to={nextPageLink}>Next page</Link>}
          </div>
        </div>
      </div>
    </div>
  </Layout>
)

export default BlogListPage

export const pageQuery = graphql`
  query BlogListPageQuery($skip: Int, $limit: Int) {
    posts: allContentfulPost(
      skip: $skip
      limit: $limit
      sort: { order: DESC, fields: [date] }
    ) {
      edges {
        node {
          ...PostTeaserFragment
        }
      }
    }
  }
`
