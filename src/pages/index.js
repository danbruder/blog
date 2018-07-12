import React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'

import Layout from '../components/layout'

const ProjectTeaser = ({ data }) => (
  <div className="br3 grow shadow-hover bg-white mw5">
    <Img
      className="br3 br--top pa3"
      sizes={get(data, 'node.image.sizes', {})}
    />
    <div className="pa3">
      <label className="tracked ttu gray fw2">Work</label>
      <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
      <p>{get(data, 'node.teaser', '')}</p>
    </div>
  </div>
)

const BlogTeaser = ({ data }) => (
  <div className="br3 grow shadow-hover bg-white black pa3 mw5">
    <label className="tracked ttu">Post</label>
    <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
    <div className="flex items-center pt3">
      <Img
        className="br-100 h2 w2 dib ba b--black-05 "
        sizes={get(data, 'node.author.avatar.sizes', {})}
      />
      <label className="i tracked ml2 ">
        By {get(data, 'node.author.name', '')} on{' '}
        {get(data, 'node.createdAt', '')}
      </label>
    </div>
    <p className="lh-copy">{get(data, 'node.summary', '')}</p>
  </div>
)

const IndexPage = ({ data }) => (
  <Layout>
    <div className="mw9 center w-100 pa5 bg-light-gray flex-ns items-center ">
      <div className="w-50-ns w-100">
        <h1 className="mt0 f1 lh-title">
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
          <a className="link ba bw1 pa3 ph4">Learn More</a>
        </div>
      </div>

      <div className="center bg-white br3 grow shadow-hover ">
        <div className=" ">
          <Img
            className="br3 br--top"
            sizes={get(data, 'featuredWork.edges[0].node.image.sizes', null)}
          />
        </div>
        <div className="pa3 br3 br--bottom ">
          <label className="tracked ttu">Featured</label>
          <h2 className="f4 ma0 tracked">
            {get(data, 'featuredWork.edges[0].node.title', '')}
          </h2>
          <p>{get(data, 'featuredWork.edges[0].node.teaser', '')}</p>
        </div>
      </div>
    </div>

    <div className="pa5 mw9 flex-ns">
      <div className="w-50-ns pa5-ns">
        <img src="https://vignette.wikia.nocookie.net/fictionalcrossover/images/c/c8/The-A-TEAM.jpg/revision/latest?cb=20160610021835" />
      </div>
      <div className="measure pa5-ns w-50-ns">
        <h1 className="fw2">About us</h1>
        <p className="lh-copy">
          DEB Associates helps companies through the entire electronics design
          process. Our team is smart, reliable, and deeply knowlegeable about
          the intricicies of circuit design, PCB layout, and EMC.
        </p>
        <label className="i lh-copy">
          What's it like working with us?{' '}
          <a className="link primary" href="/">
            Read our playbook.
          </a>
        </label>
      </div>
    </div>

    <div className="mw9 center w-100 pa5 bg-light-gray">
      <h1>Recent Projects</h1>

      <div className="flex-ns justify-around">
        {get(data, 'projects.edges', []).map((edge, key) => (
          <ProjectTeaser key={key} data={edge} />
        ))}
      </div>
    </div>

    <div className="tc mw9 center w-100 pa5 ">
      <i className="f4 tc">- We have partnered with great people -</i>
      <div className="flex-ns items-center justify-between pv5">
        <div className="mw5 pa2 grow">
          <img src="https://fiu-assets-2-syitaetz61hl2sa.stackpathdns.com/static/use-media-items/14/13518/full-1400x513/56702756/Herman_Miller-logo.png?resolution=0" />
        </div>
        <div className="mw5 pa2 grow">
          <img src="http://cascoauto.com/wp-content/uploads/2017/02/CASCO-logo-430.png" />
        </div>
        <div className="mw5 pa2 grow">
          <img src="http://s19528.pcdn.co/wp-content/uploads/2015/07/carter-fuel-systems-logo.png" />
        </div>
        <div className="mw5 pa2 grow">
          <img src="https://www.buyslider.com/img/tmp/manufacturer_1.jpg" />
        </div>
      </div>
    </div>

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

    <div className="mw9 center bg-black-90 white w-100 pa5 ">
      <i className="f4 tracked ttu">Latest Blog Posts</i>
      <div className="flex-ns items-start justify-between pv5">
        {get(data, 'blogs.edges', []).map((edge, key) => (
          <BlogTeaser key={key} data={edge} />
        ))}
      </div>
    </div>

    <div className="mw9 flex justify-between center bg--black-10 w-100 pa5 ">
      <div className="">
        <h2>Need some bandwidth?</h2>
        <div className="pt2">
          <a className="link ba bw1 pa2 ph3">Say hi</a>
        </div>
      </div>
      <div className="">
        <h2>Services</h2>
        <div className="pt2">
          <a className="link ba bw1 pa2 ph3">Say hi</a>
        </div>
      </div>
    </div>

    <div className="mw9 w-100 pa5 ">
      <hr />
      <small>DEB Associates</small>
      <small> 2018</small>
    </div>
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
          image {
            sizes(maxWidth: 1000, maxHeight: 400) {
              ...GatsbyContentfulSizes_tracedSVG
            }
          }
        }
      }
    }
    blogs: allContentfulPost(
      limit: 4
      sort: { order: DESC, fields: [createdAt] }
    ) {
      edges {
        node {
          title
          summary
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
