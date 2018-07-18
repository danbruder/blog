import React from 'react'
import PropTypes from 'prop-types'
import { StaticQuery, graphql } from 'gatsby'
import Helmet from 'react-helmet'

import Header from './header'
import Footer from './footer'
import favicon from './favicon.ico'
import 'normalize.css/normalize.css'
import 'tachyons/css/tachyons.css'
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
        title="Dan Bruder | Elixir Developer"
        link={[
          { rel: 'shortcut icon', href: `${favicon}` }
        ]}
      />
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
