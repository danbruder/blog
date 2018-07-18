import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { blogRootPath } from '../config'

import Layout from '../components/layout'
import BlogTeaser from '../components/BlogTeaser'
import AuthorTeaser from '../components/AuthorTeaser'

const BlogListPage = ({ data, pageContext }) => (
  <Layout>
    <div className="bg-gray-light ">
      <div className="mw7 center w-100 pa3 pv4-ns pa5-l ">
        {get(data, 'posts.edges', []).map((edge, key) => (
          <BlogTeaser data={edge} key={key} />
        ))}
        {pageContext &&
          pageContext.hasNextPage && (
            <Link class="flex items-center" to={pageContext.nextPageLink}>
              <small>Next page</small>
            </Link>
          )}
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
