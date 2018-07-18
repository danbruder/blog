import React from 'react'
import {  Link } from 'gatsby'
import {blogRootPath} from '../config'
import { get } from 'lodash'

export default ({data}) => (
  <div className="mw7 pa3 ph5-l">
    <span className="ma0 gray ttu ">{ get(data, 'node.date', '')} </span><span className="fw5 ttu primary pl2">{ get(data, 'node.category.title', '')}</span>
    <Link className="black link hover-green" to={`${blogRootPath}/${get(data, 'node.slug', '')}`}><h1 className="mt1 pa0">{get(data, 'node.title', '')}</h1></Link>
    <div className="lh-copy " dangerouslySetInnerHTML={{__html: get(data, 'node.summary.childMarkdownRemark.html', '')}}/>
  </div>
)

