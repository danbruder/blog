import React from 'react'
import Img from 'gatsby-image'
import { get } from 'lodash'

export default ({data}) => (
  <div className="pr3 pr5-l">
    <Img className="mb2 br-100 w3 h3 " sizes={get(data, 'profilePhoto.sizes', {})}/>
    <h2 className="ma0 f5">{get(data, 'name', '')}</h2>
    <div className="lh-copy " dangerouslySetInnerHTML={{__html: get(data, 'biography.childMarkdownRemark.html', '')}}/>
  </div>
)


