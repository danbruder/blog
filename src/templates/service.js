import React from 'react'
import Img from 'gatsby-image'
import { get } from 'lodash'

import Layout from '../components/layout'

const ServicePage = ({ data }) => (
  <Layout>
    <div className="w-100 h5">
      <Img className="w-100 h5" sizes={get(data, 'service.image.sizes', {})} />
    </div>
    <div className="mw9 center w-100  bg-light-gray">
      <article className="cf ph3 ph5-ns pv5">
        <header className="fn fl-ns w-40-ns pr4-ns">
          <time className="f6 ttu tracked gray">Service</time>
          <h1 className="mb3 mt0 lh-title">{get(data, 'service.title', '')}</h1>
          <h2 className="f4 fw3 lh-copy">{get(data, 'service.summary', '')}</h2>
        </header>
        <div className="fn fl-ns w-60-ns">
          <div
            className="f5 lh-copy  mt0-ns"
            dangerouslySetInnerHTML={{
              __html: get(data, 'service.body.childMarkdownRemark.html', ''),
            }}
          />
        </div>
      </article>
    </div>
  </Layout>
)

export default ServicePage

export const pageQuery = graphql`
  query ServiceQuery($slug: String) {
    service: contentfulSpecialty(slug: { eq: $slug }) {
      title
      summary
      id
      slug
      createdAt(formatString: "M/D/YY")
      image: hero {
        sizes(maxWidth: 3000, maxHeight: 1000) {
          ...GatsbyContentfulSizes_tracedSVG
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
