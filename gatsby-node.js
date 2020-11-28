var path = require('path')
var _ = require('lodash')

var config = require('./src/config')

exports.createPages = ({ graphql, actions }) => {
  const { createPage } = actions
  const blogTemplate = path.resolve(`src/templates/blog.js`)

  return new Promise((resolve, reject) => {
    resolve(
      graphql(
        `
          query {
            posts: allContentfulPost(sort: { order: DESC, fields: [date] }) {
              edges {
                node {
                  slug
                }
              }
            }
          }
        `
      ).then(result => {
        if (result.errors) {
          reject(result.errors)
        }

        // Create a blog page
        result.data.posts.edges.forEach(({ node }) => {
          // loop over split pages
          createPage({
            path: `${config.blogRootPath}/${node.slug}`,
            component: blogTemplate,
            context: {
              slug: node.slug,
            },
          })
        })
      })
    )
  })
}
