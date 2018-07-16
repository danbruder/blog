import React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { Link } from 'gatsby'
import Meta from '../components/meta'

import Layout from '../components/layout'

const ServiceTeaser = ({ data, index }) => (
  <div className="cf bt b--black-90 pv3">
    <Link
      className="link black db"
      to={`/services/${get(data, 'node.slug', '')}`}
    >
      <div className="fl-ns fn w-50-ns w-100 ">
        <h1 className="tl f1 tr-ns pr5 mt3">{index + 1}.</h1>
      </div>
      <div className="fl-ns fn w-50-ns w-100 ">
        <h2 className="mb0">{get(data, 'node.title', '')}</h2>
        <p className="lh-copy mt0 measure">{get(data, 'node.summary', '')}</p>
      </div>
    </Link>
  </div>
)

const ServicePage = ({ data }) => (
  <Layout>
    <Meta title="Services" url="services" />
    <div className="bg-light-gray">
      <div className="mw9 center w-100 pa3 cf pa5-ns bg-light-gray">
        <h1>Services</h1>
        <div>
          {get(data, 'services.edges', []).map((edge, key) => (
            <ServiceTeaser index={key} key={key} data={edge} />
          ))}
        </div>
      </div>
    </div>
  </Layout>
)

export default ServicePage

export const pageQuery = graphql`
  query ServicePageQuery {
    services: allContentfulSpecialty(sort: { order: ASC, fields: [weight] }) {
      edges {
        node {
          slug
          title
          summary
          image: hero {
            sizes(maxWidth: 2000, maxHeight: 1000) {
              ...GatsbyContentfulSizes_tracedSVG
            }
          }
        }
      }
    }
  }
`
