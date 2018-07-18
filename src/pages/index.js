import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import {blogRootPath} from '../config'

import Layout from '../components/layout'
import BlogTeaser from '../components/BlogTeaser'
import AuthorTeaser from '../components/AuthorTeaser'

const IndexPage = ({ data }) => (
  <Layout>
    <div className="bg-light-gray ">
      <div className="mw9 center w-100 pa3 pa5-ns bg-light-gray flex">
        <div className="w-30">
          <AuthorTeaser data={get(data, 'author', {})}/>
        </div>
        <div className="bl b--black-10 w-70">
          {get(data, 'posts.edges', []).map((edge, key) => <BlogTeaser data={edge} key={key}/>)}
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

fragment AuthorTeaserFragment on ContentfulAuthor {
    name
    biography{
      childMarkdownRemark{
        html
      }
    }
    profilePhoto{
      sizes(maxWidth:500){
        ...GatsbyContentfulSizes_tracedSVG
      }
    }
}

query IndexQuery {
  posts: allContentfulPost(sort: {order: DESC, fields: [date]}){
    edges{
      node{
        ...PostTeaserFragment
      }
    }
  }
  author: contentfulAuthor{
    ...AuthorTeaserFragment
  }
}
`
