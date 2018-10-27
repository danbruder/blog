import React from 'react'
import { Link } from 'gatsby'
import { get } from 'lodash'

export default ({ data }) => {
  return (
    <div className=" pb4">
      <div className="flex items-center ">
        <h2 className="">{get(data, 'node.title', '')}</h2>
      </div>
      <div
        className="lh-copy "
        dangerouslySetInnerHTML={{
          __html: get(data, 'node.body.childMarkdownRemark.html', ''),
        }}
      />
    </div>
  )
}
