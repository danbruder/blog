// Implement the Gatsby API “createPages”. This is called once the
// data layer is bootstrapped to let plugins create pages from data.

var path = require('path')
exports.createPages = ({ graphql, actions }) => {
  const { createPage } = actions
  const projectTemplate = path.resolve(`src/templates/project.js`)
  const serviceTemplate = path.resolve(`src/templates/service.js`)
  const blogTemplate = path.resolve(`src/templates/blog.js`)

  return new Promise((resolve, reject) => {
    // Query for markdown nodes to use in creating pages.
    resolve(
      graphql(
        `
          query {
            allContentfulOurWork(limit: 1000) {
              edges {
                node {
                  slug
                }
              }
            }
            allContentfulPost(limit: 1000) {
              edges {
                node {
                  slug
                }
              }
            }
            allContentfulSpecialty(limit: 1000) {
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

        // Create pages for each markdown file.
        result.data.allContentfulOurWork.edges.forEach(({ node }) => {
          createPage({
            path: `projects/${node.slug}`,
            component: projectTemplate,
            context: {
              slug: node.slug,
            },
          })
        })

        result.data.allContentfulPost.edges.forEach(({ node }) => {
          createPage({
            path: `blog/${node.slug}`,
            component: blogTemplate,
            context: {
              slug: node.slug,
            },
          })
        })

        result.data.allContentfulSpecialty.edges.forEach(({ node }) => {
          createPage({
            path: `services/${node.slug}`,
            component: serviceTemplate,
            context: {
              slug: node.slug,
            },
          })
        })
      })
    )
  })
}
