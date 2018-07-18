import React from 'react'
import Img from 'gatsby-image'
import { get } from 'lodash'

import Layout from '../components/layout'

const BlogPage = ({ data }) => (
  <Layout>
    <div className="bg-light-gray">
      <div className="mw8 center w-100 pa5-ns ">
        <span className="ma0 ttu gray tracked">{ get(data, 'blog.date', '')} </span><span className="fw5 ttu primary pl2">{ get(data, 'blog.category.title', '')}</span> 
        <h1 className="bb b--black-10 mv1 pb2 lh-title">{data.blog.title}</h1>
        <div className="lh-copy" dangerouslySetInnerHTML={{__html: get(data, 'blog.body.childMarkdownRemark.html', '')}}/>
      </div>
    </div>
  </Layout>
)

export default BlogPage

export const pageQuery = graphql`
  query BlogQuery($slug: String) {
    blog: contentfulPost(slug: { eq: $slug }) {
      title
      date(formatString: "MMMM D YYYY")
      category{
        title
      }
      body{
        childMarkdownRemark{
          html
          timeToRead
        }
      }
    }
  }
`
