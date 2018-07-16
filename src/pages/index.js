import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { Twitter, Linkedin } from 'react-feather'

import Layout from '../components/layout'
import Meta from '../components/meta'

const BioSocialLinks = ({ data }) => {
  const items = [
    {
      url: `https://twitter.com/${get(data, 'twitter', '')}`,
      hasVal: get(data, 'twitter', false),
      component: <Twitter />,
    },
    {
      url: `https://linkedin.com/in/${get(data, 'linkedin', '')}`,
      hasVal: get(data, 'linkedin', false),
      component: <Linkedin />,
    },
  ]
  const getItems = () =>
    items.filter(i => i.hasVal).map((i, key) => (
      <div key={key} className="">
        <a className="icon-wrap pr3 pt3 black hover-green" href={i.url}>
          {i.component}
        </a>
      </div>
    ))

  return <div className="pt3 justify-start flex">{getItems()}</div>
}

const BioTeaser = ({ data, className }) => (
  <article className={` w-100 mw6 bg-white pa4 ba b--black-10 ${className}`}>
    <div className="tc">
      <Img
        className="br-100 h4 w4 dib ba b--black-05 pa2"
        sizes={get(data, 'avatar.sizes', {})}
      />
      <h1 className="f3 mb2">{get(data, 'name', '')}</h1>
      <h2 className="f5 fw4 gray mt0">{get(data, 'position', '')}</h2>
      <hr className=" bb bw1 b--black-10" />
    </div>
    <p className="lh-copy measure center pb0 mb0 f6 black-70">
      {get(data, 'bio.bio', '')}
    </p>
    <div className="">
      <BioSocialLinks data={data} />
    </div>
  </article>
)

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
  <div className="pa3 w-100 w-50-ns w-33-l">
    <div className="grow shadow-hover bg-white ">
      <Link
        className="link black db"
        to={`/projects/${get(data, 'node.slug', '')}`}
      >
        <Img
          className=" br--top pa3 w-100 h4"
          sizes={get(data, 'node.image.sizes', {})}
        />
        <div className="pa3">
          <label className="tracked ttu gray fw2">Project</label>
          <h2 className="f4 ma0 tracked">{get(data, 'node.title', '')}</h2>
          <p>{get(data, 'node.teaser', '')}</p>
        </div>
      </Link>
    </div>
  </div>
)

const BlogTeaser = ({ data, className }) => (
  <div className={` grow shadow-hover bg-white black pa3 ${className}`}>
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
    <Meta description="Custom Electronics Design and Development" />
    <div className="bg-light-gray ">
      <div className="mw9 center w-100 pa3 pa5-ns bg-light-gray flex-ns items-center ">
        <div className="w-100 w-50-l pr3 w-100">
          <h1 className="mt0 f3 f1-l lh-title">
            Custom Electronics Design and Development
          </h1>
          <h3 className="f5 f3-l fw2 ">
            Reducing costs and expediting development. We empower companies with
            custom electronics solutions.
          </h3>
          <p className=" ">
            We offer no-risk engagements. We deliver or you don't pay.{' '}
            <i>Seriously.</i>
          </p>
          <div className="pt4">
            <Link
              to="/services/"
              className="primary link ba bw1 pa2 pa3-l ph3 ph4-l"
            >
              See our Services
            </Link>
          </div>
        </div>

        <div className=" w-100 w-50-l ma5 db center bg-white  grow shadow-hover ">
          <Link
            className="link black"
            to={`/projects/${get(data, 'featuredWork.edges[0].node.slug', '')}`}
          >
            <div className=" ">
              <Img
                className=" br--top"
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
          <div className="w5 h-auto mw5 ma4 pa2 grow">
            <Img className="" sizes={get(data, 'hm.sizes', {})} />
          </div>
          <div className="w5 h-auto mw5 ma4 pa2 grow">
            <Img className="" sizes={get(data, 'casco.sizes', {})} />
          </div>
          <div className="w5 h-auto mw5 ma4 pa2 grow">
            <Img className="" sizes={get(data, 'kessler.sizes', {})} />
          </div>
          <div className="w4 h-auto mw5 ma4 pa2 grow">
            <Img className="" sizes={get(data, 'electron.sizes', {})} />
          </div>
          <div className="mw6 w-100 h-auto mw5 ma4 pa2 grow">
            <Img className="" sizes={get(data, 'carter.sizes', {})} />
          </div>
          <div className="w5 h-auto mw4 ma4 pa2 grow">
            <Img className="" sizes={get(data, 'soundoff.sizes', {})} />
          </div>
        </div>
      </div>
    </div>

    <div className="bg-light-gray">
      <div className="mw9 center w-100 pa3 pa5-ns bg-light-gray">
        <h1>The Team</h1>

        <div className="mw9 flex flex-column flex-row-l justify-center">
          <BioTeaser className="mr2-l mt2" data={get(data, 'alina', {})} />
          <BioTeaser className="mt2" data={get(data, 'dave', {})} />
          <BioTeaser className="ml2-l mt2" data={get(data, 'dan', {})} />
        </div>
      </div>
    </div>

    <div className="bg-black-90 ">
      <div className="mw9 center white w-100 pa5 ">
        <i className="f4 tracked ttu">Latest Blog Posts</i>
        <div className="flex flex-column flex-row-l justify-center mt4">
          {get(data, 'blogs.edges', []).map((edge, key) => (
            <BlogTeaser
              key={key}
              className={`w-100 mw6 ba b--white pa4  
              ${key % 1 == 0 ? 'mr2-l mt2' : ''}
              ${key % 2 == 0 ? 'mt2' : ''}
              ${key % 3 == 0 ? 'ml2-l mt2' : ''} `}
              data={edge}
            />
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
  fragment AuthorFragment on ContentfulAuthor {
    name
    position
    bio {
      bio
      childMarkdownRemark {
        html
      }
    }
    twitter
    linkedin
    avatar {
      sizes {
        src
      }
    }
  }

  fragment ClientFragment on ContentfulAsset {
    sizes(maxWidth: 1200) {
      ...GatsbyContentfulSizes_tracedSVG
    }
  }

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
      limit: 3
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
      limit: 3
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

    dan: contentfulAuthor(name: { eq: "Dan" }) {
      ...AuthorFragment
    }
    dave: contentfulAuthor(name: { eq: "Dave" }) {
      ...AuthorFragment
    }
    alina: contentfulAuthor(name: { eq: "Alina" }) {
      ...AuthorFragment
    }
    hm: contentfulAsset(title: { regex: "/client-herman-miller/" }) {
      ...ClientFragment
    }
    carter: contentfulAsset(title: { regex: "/client-carter/" }) {
      ...ClientFragment
    }
    casco: contentfulAsset(title: { regex: "/client-casco/" }) {
      ...ClientFragment
    }
    kessler: contentfulAsset(title: { regex: "/client-kessler/" }) {
      ...ClientFragment
    }
    soundoff: contentfulAsset(title: { regex: "/client-soundoff-signal/" }) {
      ...ClientFragment
    }
    electron: contentfulAsset(title: { regex: "/client-electron/" }) {
      ...ClientFragment
    }
  }
`
