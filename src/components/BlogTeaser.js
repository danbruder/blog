import React from 'react'
import { Link } from 'gatsby'
import { blogRootPath } from '../config'
import { get } from 'lodash'

export default ({ data }) => (
  <div className="pv3 ">
    <span className="fw5 ttu primary ">
      {get(data, 'node.category.title', '')}
    </span>
    <Link
      className="black link hover-green"
      to={`${blogRootPath}/${get(data, 'node.slug', '')}`}
    >
      <h1 className="f3  mv1 pa0">{get(data, 'node.title', '')}</h1>
    </Link>
    <span className=" gray i mono ">{get(data, 'node.date', '')} </span>
    <div
      className="lh-copy "
      dangerouslySetInnerHTML={{
        __html: get(data, 'node.summary.childMarkdownRemark.html', ''),
      }}
    />
  </div>
)
