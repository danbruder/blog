import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { blogRootPath } from '../config'
import { BookOpen } from 'react-feather'
import ProjectTeaser from '../components/ProjectTeaser'

import Layout from '../components/layout'

const ProjectPage = ({ data }) => (
  <Layout>
    <div className="bg-gray-light  ">
      <div className="mw9 pa3 pa5-l center pv3 pv4-l ">
        <div className="bb b--black-10">
          <h1>Projects</h1>
        </div>
        <div className="pv5">
          {get(data, 'projects.edges', []).map((edge, key) => (
            <ProjectTeaser data={edge} key={key} />
          ))}
        </div>
      </div>
    </div>
  </Layout>
)

export default ProjectPage

export const pageQuery = graphql`
  fragment ProjectTeaserFragment on ContentfulProject {
    title
    slug
    weight
    featured
    image {
      sizes(maxWidth: 1000) {
        ...GatsbyContentfulSizes_tracedSVG
      }
    }
    body {
      childMarkdownRemark {
        html
      }
    }
  }

  query ProjectQuery {
    projects: allContentfulProject(limit: 5) {
      edges {
        node {
          ...ProjectTeaserFragment
        }
      }
    }
  }
`
