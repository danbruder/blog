import React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'

import Layout from '../components/layout'

const ProjectTeaser = ({ data }) => (
  <div className="mt5 flex justify-between    ">
    <div className=" pa3">
      <h2 className="f1 ma0 tracked">{get(data, 'node.title', '')}</h2>
      <p>{get(data, 'node.teaser', '')}</p>
    </div>
    <div className="w-40">
      <Img className=" " sizes={get(data, 'node.image.sizes', {})} />
    </div>
  </div>
)

const ProjectPage = ({ data }) => (
  <Layout>
    <div className="mw9 center w-100 pa5 bg-light-gray">
      <div className="">
        {get(data, 'projects.edges', []).map((edge, key) => (
          <ProjectTeaser key={key} data={edge} />
        ))}
      </div>
    </div>

    <div className="mw9 flex justify-between center bg--black-10 w-100 pa5 ">
      <div className="">
        <h2>Need some bandwidth?</h2>
        <div className="pt2">
          <a className="link ba bw1 pa2 ph3">Say hi</a>
        </div>
      </div>
      <div className="">
        <h2>Services</h2>
        <div className="pt2">
          <a className="link ba bw1 pa2 ph3">Say hi</a>
        </div>
      </div>
    </div>

    <div className="mw9 w-100 pa5 ">
      <hr />
      <small>DEB Associates</small>
      <small> 2018</small>
    </div>
  </Layout>
)

export default ProjectPage

export const pageQuery = graphql`
  query ProjectQuery {
    projects: allContentfulOurWork(sort: { order: ASC, fields: [weight] }) {
      edges {
        node {
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
