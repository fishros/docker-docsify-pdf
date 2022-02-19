const path = require('path')
const puppeteer = require('puppeteer')
const logger = require('./logger.js')
const runSandboxScript = require('./run-sandbox-script.js')

const renderPdf = async ({ mainMdFilename, pathToStatic, pathToPublic, pdfOptions, docsifyRendererPort }) => {
  let headless = true
  // check if --headless is passed as an argument
  const args = process.argv.slice(2)
  if (args.includes('--headless=false')) {
    headless = false
  }

  const browser = await puppeteer.launch({
    headless,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    defaultViewport: { width: 1200, height: 1000 }
  })
  try {
    const mainMdFilenameWithoutExt = path.parse(mainMdFilename).name
    const docsifyUrl = `http://localhost:${docsifyRendererPort}/#/${pathToStatic}/${mainMdFilenameWithoutExt}`

    const page = await browser.newPage()
    await page.goto(docsifyUrl, { waitUntil: 'networkidle0' })
    await page.emulateMediaType('screen')

    const renderProcessingErrors = await runSandboxScript(page, {
      mainMdFilenameWithoutExt,
      pathToStatic
    })

    if (renderProcessingErrors.length) { logger.warn('anchors processing errors', renderProcessingErrors) }

    if (!headless) await new Promise(resolve => setTimeout(resolve, 600000))

    await page.pdf({
      format: 'a4',
      printBackground: true,
      landscape: false,
      headerTemplate: '<div style="display: none"></div>',
      footerTemplate: '<p style="margin: auto;text-align: center;font-size: 8px;"><span class="pageNumber"></span>&nbsp;/&nbsp;<span class="totalPages"></span></p>',
      displayHeaderFooter: true,
      path: path.resolve(pathToPublic),
      margin: { left: '1cm', right: '1cm', top: '1cm', bottom: 70 }
    })

    return await browser.close()
  } catch (e) {
    await browser.close()
    throw e
  }
}

const htmlToPdf = ({ mainMdFilename, pathToStatic, pathToPublic, pdfOptions, docsifyRendererPort }) => async () => {
  const { closeProcess } = require('./utils.js')({ pathToStatic })
  try {
    return await renderPdf({
      mainMdFilename,
      pathToStatic,
      pathToPublic,
      pdfOptions,
      docsifyRendererPort
    })
  } catch (err) {
    logger.err('puppeteer renderer error:', err)
    await closeProcess(1)
  }
}

module.exports = config => ({
  htmlToPdf: htmlToPdf(config)
})
