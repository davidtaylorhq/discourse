import xss from "pretty-text/xss";

// add image to array if src has an upload
function addImage(uploads, token) {
  if (token.attrs) {
    for (let i = 0; i < token.attrs.length; i++) {
      if (token.attrs[i][1].indexOf("upload://") === 0) {
        uploads.push([token, i]);
        break;
      }
    }
  }
}

function attr(name, value) {
  if (value) {
    return `${name}="${xss.escapeAttrValue(value)}"`;
  }

  return name;
}

function uploadLocatorString(url) {
  return `___REPLACE_UPLOAD_SRC_${url}___`;
}

function findUploadsInHtml(uploads, blockToken) {
  // Slightly misusing our HTML sanitizer to look for upload://
  // image src attributes, and replace them with a placeholder
  blockToken.content = xss(blockToken.content, {
    onTag(tag, html, options) {
      // We're not using this for sanitizing, so allow all tags through
      options.isWhite = true;
    },
    onTagAttr(tag, name, value) {
      if (tag === "img" && name === "src" && value.startsWith("upload://")) {
        uploads.push([blockToken, value]);
        return uploadLocatorString(value);
      }
      return attr(name, value);
    }
  });
}

function rule(state) {
  let uploads = [];

  for (let i = 0; i < state.tokens.length; i++) {
    let blockToken = state.tokens[i];

    if (blockToken.tag === "img" || blockToken.tag === "a") {
      addImage(uploads, blockToken);
    }

    if (blockToken.type === "html_block") {
      findUploadsInHtml(uploads, blockToken);
    }

    if (!blockToken.children) continue;

    for (let j = 0; j < blockToken.children.length; j++) {
      let token = blockToken.children[j];

      if (token.tag === "img" || token.tag === "a") addImage(uploads, token);
    }
  }

  if (uploads.length > 0) {
    let srcList = uploads.map(([token, srcIndex]) => {
      if (token.type === "html_block") {
        return srcIndex;
      }
      return token.attrs[srcIndex][1];
    });

    // In client-side cooking, this lookup returns nothing
    // This means we set data-orig-src, and let decorateCooked
    // lookup the image URLs asynchronously
    let lookup = state.md.options.discourse.lookupUploadUrls;
    let longUrls = (lookup && lookup(srcList)) || {};

    uploads.forEach(([token, srcIndex]) => {
      let origSrc =
        token.type === "html_block" ? srcIndex : token.attrs[srcIndex][1];
      let mapped = longUrls[origSrc];

      if (token.type === "html_block") {
        const locator = uploadLocatorString(srcIndex);
        let attrs = [];

        if (mapped) {
          attrs.push(
            attr("src", mapped.url),
            attr("data-base62-sha1", mapped.base62_sha1)
          );
        } else {
          attrs.push(
            attr(
              "src",
              state.md.options.discourse.getURL("/images/transparent.png")
            ),
            attr("data-orig-src", origSrc)
          );
        }

        token.content = token.content.replace(locator, attrs.join(" "));
        return;
      }

      switch (token.tag) {
        case "img":
          if (mapped) {
            token.attrs[srcIndex][1] = mapped.url;
            token.attrs.push(["data-base62-sha1", mapped.base62_sha1]);
          } else {
            // no point putting a transparent .png for audio/video
            if (token.content.match(/\|video|\|audio/)) {
              token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
                "/404"
              );
            } else {
              token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
                "/images/transparent.png"
              );
            }

            token.attrs.push(["data-orig-src", origSrc]);
          }
          break;
        case "a":
          if (mapped) {
            // when secure media is enabled we want the full /secure-media-uploads/
            // url to take advantage of access control security
            if (
              state.md.options.discourse.limitedSiteSettings.secureMedia &&
              mapped.url.indexOf("secure-media-uploads") > -1
            ) {
              token.attrs[srcIndex][1] = mapped.url;
            } else {
              token.attrs[srcIndex][1] = mapped.short_path;
            }
          } else {
            token.attrs[srcIndex][1] = state.md.options.discourse.getURL(
              "/404"
            );

            token.attrs.push(["data-orig-href", origSrc]);
          }

          break;
      }
    });
  }
}

export function setup(helper) {
  const opts = helper.getOptions();
  if (opts.previewing) helper.whiteList(["img.resizable"]);

  helper.whiteList([
    "img[data-orig-src]",
    "img[data-base62-sha1]",
    "a[data-orig-href]"
  ]);

  helper.registerPlugin(md => {
    md.core.ruler.push("upload-protocol", rule);
  });
}
