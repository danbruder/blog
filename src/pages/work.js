import React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { Link } from 'gatsby'
import Layout from '../components/layout'

const ProjectTeaser = ({ data }) => (
  <div className="br3 grow shadow-hover ma3 bg-white mw5">
    <Link className="link black" to={`/work/${data.node.slug}`}>
      <Img
        className="br3 br--top pa3"
        sizes={get(data, 'node.image.sizes', {})}
      />
      <div className="pa3">
        <label className="tracked ttu gray fw2">Work</label>
        <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
        <p>{get(data, 'node.teaser', '')}</p>
      </div>
    </Link>
  </div>
)

const ProjectPage = ({ data }) => (
  <Layout>
    <div className="mw9 center w-100 pa5 bg-light-gray">
      <h1 className="f1 lh-title tc">Recent Projects</h1>
      <h2 className="f3 fw3 tc pb5">
        A collection of recent projects and practice areas
      </h2>
      <div className="flex flex-wrap">
        {get(data, 'projects.edges', []).map((edge, key) => (
          <ProjectTeaser key={key} data={edge} />
        ))}
      </div>
    </div>
  </Layout>
)

export default ProjectPage

export const pageQuery = graphql`
  query ProjectPageQuery {
    projects: allContentfulOurWork(sort: { order: ASC, fields: [weight] }) {
      edges {
        node {
          slug
          title
          teaser
          image {
            sizes(maxWidth: 2000, maxHeight: 1000) {
              ...GatsbyContentfulSizes_tracedSVG
            }
          }
        }
      }
    }
  }
`
