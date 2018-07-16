import React from 'react'
import { StaticQuery, graphql } from 'gatsby'
import { Link } from 'gatsby'
import moment from 'moment'
import { get } from 'lodash'

const Footer = () => (
  <StaticQuery
    query={graphql`
      query FooterQuery {
        contentfulFooter {
          aboutUs {
            childMarkdownRemark {
              html
            }
          }
        }
      }
    `}
    render={data => (
      <div className=" bg--black-10 ">
        <div className="mw9 center f6 w-100  pa5-ns ">
          <div className="justify-start items-start flex flex-wrap ">
            <div className="pa3 mw5">
              <h3>Like what you see?</h3>
              <div className="pt2">
                <Link to="/contact" className="link ba bw1 pa2 ph3">
                  Say hi
                </Link>
              </div>
            </div>

            <div className="pa3 mw5">
              <h2 className="f5">Services</h2>
              <div className="pt2">
                <Link to="/services/circuit-design" className="link">
                  Circuit Design
                </Link>
              </div>
              <div className="pt2">
                <Link to="/services/design-for-emc" className="link">
                  Design for EMC
                </Link>
              </div>
              <div className="pt2">
                <Link to="/services/software-development" className="link">
                  Software Development
                </Link>
              </div>
            </div>

            <div className="pa3 mw5">
              <h2 className="f5">Explore</h2>
              <div className="pt2">
                <Link to="/current-conditions" className="link">
                  Current Office Conditions
                </Link>
              </div>
            </div>

            <div className="pa3 mw5">
              <h2 className="f5">Connect</h2>
              <div className="pt2">
                <a
                  href="https://www.twitter.com/debassociates/"
                  className="link"
                >
                  Twitter
                </a>
              </div>
              <div className="pt2">
                <a
                  href="https://www.linkedin.com/company/16260983/"
                  className="link"
                >
                  Linkdin
                </a>
              </div>
              <div className="pt2">
                <a
                  href="https://www.facebook.com/debassociates/"
                  className="link"
                >
                  Facebook
                </a>
              </div>
              <div className="pt2">
                <a
                  href="https://www.instagram.com/debassociates/"
                  className="link"
                >
                  Instagram
                </a>
              </div>
            </div>

            <div className="pa3 mw5">
              <h2 className="f5">Links</h2>
              <div className="pt2">
                <Link to="/services" className="link">
                  Services
                </Link>
              </div>
              <div className="pt2">
                <Link to="/projects" className="link">
                  Projects
                </Link>
              </div>
              <div className="pt2">
                <Link to="/blog" className="link">
                  Blog
                </Link>
              </div>
              <div className="pt2">
                <Link to="/contact" className="link">
                  Contact
                </Link>
              </div>
            </div>

            <div className="measure pa3">
              <h2 className="f5">About Us</h2>
              <p
                className="lh-copy"
                dangerouslySetInnerHTML={{
                  __html: get(
                    data,
                    'contentfulFooter.aboutUs.childMarkdownRemark.html',
                    ''
                  ),
                }}
              />
            </div>
          </div>
          <div className="pa3 ">
            <hr />
            <small>DEB Associates</small>{' '}
            <small>{moment().format('YYYY')}</small>
          </div>
        </div>
      </div>
    )}
  />
)

export default Footer
//<label className="i lh-copy">
//What's it like working with us?{' '}
//<a className="link primary" href="/">
//Read our playbook.
//</a>
//</label>
