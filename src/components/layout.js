import React from 'react'
import PropTypes from 'prop-types'
import { StaticQuery, graphql } from 'gatsby'
import Helmet from 'react-helmet'

import Header from './header'
import Footer from './footer'
import favicon from './favicon.ico'
import 'normalize.css/normalize.css'
import 'tachyons/css/tachyons.css'
// layouts/index.js
import 'prismjs/themes/prism.css'
import './layout.css'

const Layout = ({ children, data }) => (
  <StaticQuery
    query={graphql`
      query SiteTitleQuery {
        site {
          siteMetadata {
            title
          }
        }
      }
    `}
    render={data => (
      <>
        <Helmet
          title="Dan Bruder | Software Developer"
          link={[{ rel: 'shortcut icon', href: `${favicon}` }]}
        >
          <meta
            name="google-site-verification"
            content="Mf0hCpk6x3lpvPrl2qBdhVROvsZBRn2JTiciS2v-OJg"
          />
          <meta
            name="google-site-verification"
            content="Mf0hCpk6x3lpvPrl2qBdhVROvsZBRn2JTiciS2v-OJg"
          />
        </Helmet>
        <Header siteTitle={data.site.siteMetadata.title} />
        <div className="">{children}</div>
        <Footer />
      </>
    )}
  />
)

Layout.propTypes = {
  children: PropTypes.node.isRequired,
}

export default Layout
