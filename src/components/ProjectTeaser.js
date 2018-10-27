import React from 'react'
import { Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'

export default ({ data }) => {
  const featured = true
  return (
    <div className=" pv2">
      <section className={`${!featured ? '' : ''} center `}>
        <article className="mb5 b--black-10">
          <div className="flex flex-column flex-row-ns">
            {featured && (
              <div className="pr3-ns mb4 mb0-ns w-100 w-40-ns">
                <Img
                  sizes={get(data, 'node.image.sizes', {})}
                  className="db"
                  alt="Photo of a dimly lit room with a computer interface terminal."
                />
              </div>
            )}
            <div className="w-100 w-60-ns pl3-ns">
              <h1 className="f3   mt0 lh-title">
                {get(data, 'node.title', '')}
              </h1>
              <div
                className="lh-copy "
                dangerouslySetInnerHTML={{
                  __html: get(data, 'node.body.childMarkdownRemark.html', ''),
                }}
              />
            </div>
          </div>
        </article>
      </section>
    </div>
  )
}
