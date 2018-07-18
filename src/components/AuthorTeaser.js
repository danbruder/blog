import React from 'react'
import Img from 'gatsby-image'
import { StaticQuery, graphql } from 'gatsby'
import { get } from 'lodash'
import { Linkedin, Twitter } from 'react-feather'

export default ({ data }) => (
  <StaticQuery
    query={graphql`
      query AuthorTeaserQuery {
        author: contentfulAuthor {
          name
          biography {
            childMarkdownRemark {
              html
            }
          }
          profilePhoto {
            sizes(maxWidth: 500) {
              ...GatsbyContentfulSizes_tracedSVG
            }
          }
        }
      }
    `}
    render={data => (
      <div className="pr3 pr5-l">
        <Img
          className="mb2 br-100 w3 h3 "
          sizes={get(data, 'author.profilePhoto.sizes', {})}
        />
        <h2 className="ma0 f5">{get(data, 'author.name', '')}</h2>
        <div
          className="lh-copy "
          dangerouslySetInnerHTML={{
            __html: get(data, 'author.biography.childMarkdownRemark.html', ''),
          }}
        />
      </div>
    )}
  />
)
