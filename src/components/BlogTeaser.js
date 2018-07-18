import React from 'react'
import { Link } from 'gatsby'
import { blogRootPath } from '../config'
import { get } from 'lodash'
import { Calendar, Clock } from 'react-feather'

export default ({ data }) => {
  const timeToRead = get(data, 'node.body.childMarkdownRemark.timeToRead', 0)
  const timeToReadSuffix = timeToRead != 1 ? 'minutes' : 'minute'

  return (
    <div className=" pb4">
      <div className="flex items-center ">
        <span className="fw5 ttu primary pr2">
          {get(data, 'node.category.title', '')}
        </span>
      </div>
      <Link
        className="black link hover-green"
        to={`${blogRootPath}/${get(data, 'node.slug', '')}`}
      >
        <h1 className="f3  mv1 pa0">{get(data, 'node.title', '')}</h1>
      </Link>
      <div className="pv2 ma0  f7 gray flex items-center">
        <Calendar className="h1 w1" />
        <span className="fw3  mono ml2 mr3 ">{get(data, 'node.date', '')}</span>
        <Clock className="h1 w1" />
        <span className="fw3 mono ml2 ">
          {timeToRead} {timeToReadSuffix}
        </span>
      </div>
      <div
        className="lh-copy "
        dangerouslySetInnerHTML={{
          __html: get(data, 'node.summary.childMarkdownRemark.html', ''),
        }}
      />
    </div>
  )
}
