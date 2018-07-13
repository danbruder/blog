import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import hm from './img/hm.jpg'
import cas from './img/cas.jpg'
import car from './img/car.jpg'
import kes from './img/kes.jpg'

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

const ProjectTeaser = ({ data }) => (
  <div className="ma3 br3 grow shadow-hover bg-white w-100 mw5-ns">
    <Link className="link black db" to={`/work/${get(data, 'node.slug', '')}`}>
      <Img
        className="br3 br--top pa3 dn db-ns"
        sizes={get(data, 'node.image.sizes', {})}
      />
      <div className="pa3">
        <label className="tracked ttu gray fw2">Work</label>
        <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
        <p>{get(data, 'node.teaser', '')}</p>
      </div>
    </Link>
  </div>
)

const BlogTeaser = ({ data, className }) => (
  <div className={`br3 grow shadow-hover bg-white black pa3 ${className}`}>
    <Link className="link black" to={`/blog/${get(data, 'node.slug', '')}`}>
      <label className="tracked ttu">Post</label>
      <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
      <div className="flex items-center pt3">
        <Img
          className="br-100 h2 w2 dib ba b--black-05 "
          sizes={get(data, 'node.author.avatar.sizes', {})}
        />
        <label className="i  ml2 ">
          {get(data, 'node.createdAt', '')} by{' '}
          {get(data, 'node.author.name', '')}
        </label>
      </div>
      <p className="lh-copy">{get(data, 'node.summary', '')}</p>
    </Link>
  </div>
)

const IndexPage = ({ data }) => (
  <Layout>
    <div className="bg-light-gray ">
      <div className="mw9 center w-100 pa3 pa5-ns bg-light-gray flex-ns items-center ">
        <div className="w-50-ns pr3 w-100">
          <h1 className="mt0 f2 f1-ns lh-title">
            Custom Electronics Design and Development
          </h1>
          <h3 className="f3 fw2 ">
            Reducing costs and expiditing development. We empower companies with
            custom electronics solutions.
          </h3>
          <p className=" ">
            We offer no-risk engagements. We deliver or you don't pay.{' '}
            <i>Seriously.</i>
          </p>
          <div className="pt4">
            <Link to="/services/" className="primary link ba bw1 pa3 ph4">
              See our Services
            </Link>
          </div>
        </div>

        <div className="w-50-ns w-100 ma5 db center bg-white br3 grow shadow-hover ">
          <Link
            className="link black"
            to={`/work/${get(data, 'featuredWork.edges[0].node.slug', '')}`}
          >
            <div className=" ">
              <Img
                className="br3 br--top"
                sizes={get(
                  data,
                  'featuredWork.edges[0].node.image.sizes',
                  null
                )}
              />
            </div>
            <div className="pa3 br3 br--bottom ">
              <label className="tracked ttu">Featured</label>
              <h2 className="f4 ma0 tracked">
                {get(data, 'featuredWork.edges[0].node.title', '')}
              </h2>
              <p>{get(data, 'featuredWork.edges[0].node.teaser', '')}</p>
            </div>
          </Link>
        </div>
      </div>
    </div>

    <div className="bg-white ">
      <div className="pa3 pa5-ns bg-white center  mw9 cf">
        <h1>Services</h1>
        <div>
          {get(data, 'services.edges', []).map((edge, key) => (
            <ServiceTeaser index={key} key={key} data={edge} />
          ))}
        </div>
      </div>
    </div>

    <div className="bg-light-gray">
      <div className="tc mw9 center w-100 pa3 pa5-ns bg-light-gray">
        <h1>Recent Projects</h1>

        <div className="tl flex flex-wrap justify-center">
          {get(data, 'projects.edges', []).map((edge, key) => (
            <ProjectTeaser key={key} data={edge} />
          ))}
        </div>
      </div>
    </div>

    <div className="bg-white">
      <div className="tc mw9 center w-100 pa5 ">
        <i className="f4 tc">- We have partnered with great people -</i>
        <div className="flex flex-wrap items-center justify-center pv5">
          <div className="mw5 ma3 pa2 grow">
            <img src={hm} />
          </div>
          <div className="mw5 ma3 pa2 grow">
            <img src={cas} />
          </div>
          <div className="mw5 ma3 pa2 grow">
            <img src={car} />
          </div>
          <div className="mw5 ma3 pa2 grow">
            <img src={kes} />
          </div>
        </div>
      </div>
    </div>

    <div className="bg-light-gray">
      <div className="mw9 center w-100 pa5 bg-light-gray">
        <h1>The Team</h1>

        <div className="mw9 flex-ns justify-around items-center">
          <article className="w-33-ns center bg-white br3 pa3 pa4-ns ma3 ba b--black-10">
            <div className="tc">
              <img
                src="https://media.licdn.com/dms/image/C4D03AQFDDSvESyTsuQ/profile-displayphoto-shrink_800_800/0?e=1536796800&v=beta&t=Iv0_KdSkyFLXEgMueLxxUigocrfo9sXkFGzUAdA_Vrw"
                className="br-100 h4 w4 dib ba b--black-05 pa2"
                title="Photo of a kitty staring at you"
              />
              <h1 className="f3 mb2">Alina Barnett</h1>
              <h2 className="f5 fw4 gray mt0">Engineer</h2>
              <hr className="mw3 bb bw1 b--black-10" />
            </div>
            <p className="lh-copy measure center f6 black-70">
              Alina is a software engineer
            </p>
          </article>

          <article className="w-33-ns  center bg-white br3 pa3 pa4-ns ma3 ba zoom b--black-10">
            <div className="tc">
              <img
                src="https://media.licdn.com/dms/image/C4D03AQG_key8Uv4aUw/profile-displayphoto-shrink_800_800/0?e=1536796800&v=beta&t=DkYw7QmIQy6OUQK8zkQKz-RP2l3xeNste_bBewTME9I"
                className="br-100 h4 w4 dib ba b--black-05 pa2"
                title="Photo of a kitty staring at you"
              />
              <h1 className="f3 mb2">Dave Bruder</h1>
              <h2 className="f5 fw4 gray mt0">Principle</h2>
              <hr className="mw3 bb bw1 b--black-10" />
            </div>
            <p className="lh-copy measure center f6 black-70">
              Dave has been designing electronics as a consultatnt for the last
              decade.
            </p>
          </article>

          <article className="w-33-ns center bg-white br3 pa3 pa4-ns ma3 ba b--black-10">
            <div className="tc">
              <img
                src="https://s.gravatar.com/avatar/f3ecddbb2495c2bd92ca710df5f47c50?s=80&r=g"
                className="br-100 h4 w4 dib ba b--black-05 pa2"
                title="Photo of a kitty staring at you"
              />
              <h1 className="f3 mb2">Dan Bruder</h1>
              <h2 className="f5 fw4 gray mt0">Engineer</h2>
              <hr className="mw3 bb bw1 b--black-10" />
            </div>
            <p className="lh-copy measure center f6 black-70">
              Dan is a software engineer with a background in web development.
            </p>
          </article>
        </div>
      </div>
    </div>

    <div className="bg-black-90 ">
      <div className="mw9 center bg-black-90 white w-100 pa5 ">
        <i className="f4 tracked ttu">Latest Blog Posts</i>
        <div className="flex flex-wrap">
          {get(data, 'blogs.edges', []).map((edge, key) => (
            <div key={key} className="w-33-ns w-100 pa3">
              <BlogTeaser className="w-100" data={edge} />
            </div>
          ))}
        </div>
      </div>
    </div>
    <script
      type="text/javascript"
      dangerouslySetInnerHTML={{
        __html: `window.$crisp=[];window.CRISP_WEBSITE_ID="fc600f50-ee58-407f-903b-8184c5952765";(function(){d=document;s=d.createElement("script");s.src="https://client.crisp.chat/l.js";s.async=1;d.getElementsByTagName("head")[0].appendChild(s);})();`,
      }}
    />
  </Layout>
)

export default IndexPage

export const pageQuery = graphql`
  query IndexQuery {
    featuredWork: allContentfulOurWork(
      limit: 1
      sort: { order: ASC, fields: [weight] }
    ) {
      edges {
        node {
          title
          teaser
          slug
          image {
            sizes(maxWidth: 1000) {
              ...GatsbyContentfulSizes_tracedSVG
            }
          }
        }
      }
    }
    projects: allContentfulOurWork(
      limit: 4
      sort: { order: ASC, fields: [weight] }
    ) {
      edges {
        node {
          title
          teaser
          slug
          image {
            sizes(maxWidth: 1000, maxHeight: 400) {
              ...GatsbyContentfulSizes_tracedSVG
            }
          }
        }
      }
    }
    services: allContentfulSpecialty(sort: { order: ASC, fields: [weight] }) {
      edges {
        node {
          title
          teaser
          slug
          summary
        }
      }
    }
    blogs: allContentfulPost(
      limit: 6
      sort: { order: DESC, fields: [createdAt] }
    ) {
      edges {
        node {
          title
          summary
          slug
          createdAt(formatString: "M/D/YY")
          author {
            name
            avatar {
              sizes(maxWidth: 200) {
                ...GatsbyContentfulSizes_tracedSVG
              }
            }
          }
        }
      }
    }
  }
`
