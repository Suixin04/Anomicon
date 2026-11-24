// Anomicon DOM 提取脚本：在 ArkWeb 离屏页中运行，把 Wikidot 页面正文
// 序列化为结构化 JSON。返回值为 JSON 字符串，始终包含 ok 字段。
// 所有样式标签与结构映射见 ScpDocument.ets 的 ScpBlockType/ScpTextStyle。
function __anomiconExtract() {
  var out = {
    parserVersion: 9,
    ok: false,
    error: '',
    title: '',
    rating: '',
    pageVersion: '',
    tags: [],
    images: [],
    blocks: [],
    footnotes: [],
    warnings: []
  };
  try {
    var pc = document.getElementById('page-content');
    if (!pc) {
      throw new Error('page-content node not found');
    }
    var titleEl = document.getElementById('page-title');
    out.title = titleEl ? titleEl.textContent.trim() : '';

    var rateEl = document.querySelector('span[id^="prw"]');
    out.rating = rateEl ? rateEl.textContent.trim() : '';

    var pageInfo = document.getElementById('page-info');
    out.pageVersion = pageInfo ? pageInfo.textContent.trim() : '';

    var tagLinks = document.querySelectorAll('.page-tags a');
    for (var ti = 0; ti < tagLinks.length; ti++) {
      var tagText = tagLinks[ti].textContent.trim();
      if (tagText.length > 0 && out.tags.indexOf(tagText) < 0) {
        out.tags.push(tagText);
      }
    }

    function addWarning(code) {
      if (out.warnings.indexOf(code) < 0) {
        out.warnings.push(code);
      }
    }

    function classOf(node) {
      var value = node.className || '';
      if (typeof value === 'string') {
        return value;
      }
      return value.baseVal || '';
    }

    var NOISE_ANCHOR_EXACT = [
      'page-content', 'page-title', 'page-info', 'ads', 'adend',
      'toc-action-bar', 'toc-list', 'u-credit-view', 'u-credit-otherwise',
      'u-adult-warning'
    ];
    var BLOCK_STRUCTURE_SET = {
      div: 1, p: 1, blockquote: 1, table: 1, ul: 1, ol: 1, pre: 1, hr: 1,
      section: 1, article: 1, h1: 1, h2: 1, h3: 1, h4: 1, h5: 1, h6: 1,
      header: 1, footer: 1, nav: 1, figure: 1, figcaption: 1, form: 1,
      audio: 1, video: 1, canvas: 1, svg: 1, object: 1, math: 1
    };

    function normalizeAnchor(raw) {
      var text = String(raw || '').trim();
      while (text.charAt(0) === '#') {
        text = text.substring(1).trim();
      }
      if (!text) {
        return '';
      }
      try {
        text = decodeURIComponent(text);
      } catch (err) {
      }
      return text.trim().toLowerCase();
    }

    function isNoiseAnchor(normalized) {
      if (!normalized || normalized.length > 128) {
        return true;
      }
      if (NOISE_ANCHOR_EXACT.indexOf(normalized) >= 0) {
        return true;
      }
      return normalized.indexOf('prw') === 0 ||
        normalized.indexOf('footnote-') === 0 ||
        normalized.indexOf('footnoteref-') === 0;
    }

    function mergeAnchors(target, incoming) {
      for (var i = 0; i < incoming.length && target.length < 16; i++) {
        var norm = normalizeAnchor(incoming[i]);
        if (norm && !isNoiseAnchor(norm) && target.indexOf(norm) < 0) {
          target.push(norm);
        }
      }
    }

    function directNodeAnchors(node) {
      var list = [];
      var idAttr = node.getAttribute ? (node.getAttribute('id') || '') : '';
      if (idAttr) {
        mergeAnchors(list, [idAttr]);
      }
      if (node.tagName && node.tagName.toLowerCase() === 'a') {
        var nameAttr = node.getAttribute('name') || '';
        if (nameAttr) {
          mergeAnchors(list, [nameAttr]);
        }
      }
      return list;
    }

    function collectInlineAnchors(node, output) {
      mergeAnchors(output, directNodeAnchors(node));
      for (var child = node.firstChild; child; child = child.nextSibling) {
        if (child.nodeType !== 1) {
          continue;
        }
        var childTag = child.tagName.toLowerCase();
        if (BLOCK_STRUCTURE_SET[childTag]) {
          continue;
        }
        collectInlineAnchors(child, output);
      }
    }

    function attachAnchors(block, anchors) {
      if (!block || !anchors || anchors.length === 0) {
        return;
      }
      var list = block.anchors ? block.anchors.slice() : [];
      mergeAnchors(list, anchors);
      if (list.length > 0) {
        block.anchors = list;
      }
    }

    function consumeAnchors(block, pending, extra) {
      if (!block) {
        return;
      }
      var combined = [];
      if (pending && pending.length > 0) {
        mergeAnchors(combined, pending);
        pending.length = 0;
      }
      if (extra && extra.length > 0) {
        mergeAnchors(combined, extra);
      }
      attachAnchors(block, combined);
    }

    function imageSourceOf(image) {
      return image.currentSrc || image.src || image.getAttribute('src') || '';
    }

    function recordImage(image, caption) {
      var source = imageSourceOf(image);
      if (source.length === 0) {
        return '';
      }
      for (var index = 0; index < out.images.length; index++) {
        if (out.images[index].src === source) {
          if (out.images[index].caption.length === 0 && caption.length > 0) {
            out.images[index].caption = caption;
          }
          return source;
        }
      }
      out.images.push({ src: source, caption: caption });
      return source;
    }

    function rubyTextOf(ruby) {
      var base = '';
      var readings = [];
      for (var child = ruby.firstChild; child; child = child.nextSibling) {
        if (child.nodeType === 1) {
          var childTag = child.tagName.toLowerCase();
          if (childTag === 'rt') {
            var reading = child.textContent.trim();
            if (reading.length > 0) {
              readings.push(reading);
            }
            continue;
          }
          if (childTag === 'rp') {
            continue;
          }
        }
        base += child.textContent || child.nodeValue || '';
      }
      if (readings.length === 0) {
        return base;
      }
      return base + '（' + readings.join(' / ') + '）';
    }

    function readableTextOf(node) {
      if (node.nodeType === 3) {
        return node.nodeValue || '';
      }
      if (node.nodeType !== 1) {
        return '';
      }
      var tag = node.tagName.toLowerCase();
      if (tag === 'img' || tag === 'rp' || tag === 'rt') {
        return '';
      }
      if (tag === 'ruby') {
        addWarning('degraded:ruby-annotation');
        return rubyTextOf(node);
      }
      var text = '';
      for (var child = node.firstChild; child; child = child.nextSibling) {
        text += readableTextOf(child);
      }
      return text;
    }

    function appendImageSpan(result, image, target) {
      var alt = (image.getAttribute('alt') || image.getAttribute('title') || '').trim();
      var source = recordImage(image, alt);
      var label = alt.length > 0 ? '图片：' + alt : '图片';
      result.push({
        s: (target || source).length > 0 ? 'link' : 'plain',
        u: target || source,
        t: '[' + label + ']'
      });
      addWarning('degraded:inline-image-placement');
    }

    function spansOf(el, inherited, skipNestedLists) {
      var result = [];
      // HTML uses whitespace-only text nodes both as inline separators and as
      // pretty-print indentation.  Keep a single separator only when it sits
      // between readable siblings; dropping every such node turns
      // "<strong>foo</strong> <em>bar</em>" into "foobar", while preserving
      // indentation would add random leading/trailing spaces to each block.
      function hasReadableFollowingSibling(node) {
        for (var sibling = node.nextSibling; sibling; sibling = sibling.nextSibling) {
          if (sibling.nodeType === 3) {
            if ((sibling.nodeValue || '').trim().length > 0) {
              return true;
            }
            continue;
          }
          if (sibling.nodeType !== 1) {
            continue;
          }
          var siblingTag = sibling.tagName.toLowerCase();
          if (siblingTag === 'br') {
            return false;
          }
          if (siblingTag !== 'ul' && siblingTag !== 'ol' &&
              readableTextOf(sibling).trim().length > 0) {
            return true;
          }
        }
        return false;
      }

      function walk(node, style) {
        if (node.nodeType === 3) {
          var raw = node.nodeValue;
          if (raw && raw.trim().length > 0) {
            result.push({ s: style, t: raw });
          } else if (raw && result.length > 0 && hasReadableFollowingSibling(node)) {
            result.push({ s: style, t: ' ' });
          }
          return;
        }
        if (node.nodeType !== 1) {
          return;
        }
        var tag = node.tagName.toLowerCase();
        var cls = classOf(node);
        if (tag === 'br') {
          result.push({ s: style, t: '\n' });
          return;
        }
        if (skipNestedLists && (tag === 'ul' || tag === 'ol')) {
          return;
        }
        if (tag === 'img') {
          appendImageSpan(result, node, '');
          return;
        }
        if (tag === 'ruby') {
          var rubyText = rubyTextOf(node);
          if (rubyText.trim().length > 0) {
            result.push({ s: style, t: rubyText });
          }
          addWarning('degraded:ruby-annotation');
          return;
        }
        if (tag === 'sup' && cls.indexOf('footnoteref') >= 0) {
          var supLink = node.querySelector('a');
          var supLabel = supLink ? supLink.textContent : '';
          result.push({
            s: 'footnote',
            r: supLink ? (supLink.id || '').replace('footnoteref-', '') : '',
            t: supLabel.trim().replace(/^\[+|\]+$/g, '').trim()
          });
          return;
        }
        if (tag === 'a') {
          if (cls.indexOf('footnoteref') >= 0) {
            result.push({
              s: 'footnote',
              r: (node.id || '').replace('footnoteref-', ''),
              t: (node.textContent || '').trim().replace(/^\[+|\]+$/g, '').trim()
            });
            return;
          }
          var href = node.getAttribute('href') || '';
          var linkText = readableTextOf(node).trim();
          if (href !== 'javascript:;' && linkText.length > 0) {
            result.push({ s: 'link', u: href, t: linkText });
          } else if (href === 'javascript:;' && linkText.length > 0) {
            result.push({ s: style, t: linkText });
          }
          var linkImages = node.querySelectorAll('img');
          for (var linkImageIndex = 0; linkImageIndex < linkImages.length; linkImageIndex++) {
            appendImageSpan(result, linkImages[linkImageIndex], href !== 'javascript:;' ? href : '');
          }
          return;
        }
        var nextStyle = style;
        if (tag === 'strong' || tag === 'b') {
          nextStyle = 'strong';
        } else if (tag === 'em' || tag === 'i') {
          nextStyle = 'em';
        } else if (tag === 'del' || tag === 's' || tag === 'strike') {
          nextStyle = 'del';
        } else if (tag === 'code' || tag === 'tt') {
          nextStyle = 'code';
        }
        for (var child = node.firstChild; child; child = child.nextSibling) {
          walk(child, nextStyle);
        }
      }
      walk(el, inherited || 'plain');
      return result;
    }

    function directListItems(list) {
      var result = [];
      for (var child = list.firstChild; child; child = child.nextSibling) {
        if (child.nodeType === 1 && child.tagName.toLowerCase() === 'li') {
          result.push(child);
        }
      }
      return result;
    }

    function walkNestedLists(root, blocks, depth) {
      for (var child = root.firstChild; child; child = child.nextSibling) {
        if (child.nodeType !== 1) {
          continue;
        }
        var tag = child.tagName.toLowerCase();
        if (tag === 'ul' || tag === 'ol') {
          walkList(child, blocks, depth);
        } else {
          walkNestedLists(child, blocks, depth);
        }
      }
    }

    // 当前文档模型尚无列表块。先降级成带稳定前缀的段落，确保内容与顺序不丢失。
    function walkList(list, blocks, depth) {
      var ordered = list.tagName.toLowerCase() === 'ol';
      var start = ordered ? parseInt(list.getAttribute('start') || '1', 10) : 1;
      if (isNaN(start)) {
        start = 1;
      }
      var items = directListItems(list);
      for (var index = 0; index < items.length; index++) {
        var prefix = '';
        for (var indent = 0; indent < depth; indent++) {
          prefix += '  ';
        }
        prefix += ordered ? String(start + index) + '. ' : '• ';
        var itemSpans = spansOf(items[index], 'plain', true);
        if (itemSpans.length > 0) {
          itemSpans.unshift({ s: 'plain', t: prefix });
          blocks.push({ k: 'paragraph', spans: itemSpans });
        }
        walkNestedLists(items[index], blocks, depth + 1);
      }
      addWarning('degraded:list-layout');
    }

    function unsupportedFallback(node, tag, blocks) {
      var labels = {
        audio: '音频',
        video: '视频',
        canvas: '画布',
        svg: '矢量图',
        object: '外部对象',
        math: '数学公式'
      };
      var fallbackSpans = spansOf(node);
      if (fallbackSpans.length === 0) {
        var source = node.getAttribute('src') || node.getAttribute('data') || '';
        fallbackSpans.push({
          s: source.length > 0 ? 'link' : 'plain',
          u: source,
          t: '[暂不支持的' + labels[tag] + '内容]'
        });
      }
      blocks.push({ k: 'paragraph', spans: fallbackSpans });
      addWarning('unsupported:' + tag);
    }

    function walkBlocks(root, blocks, pendingAnchors) {
      if (!pendingAnchors) {
        pendingAnchors = [];
      }
      for (var node = root.firstChild; node; node = node.nextSibling) {
        walkBlockNode(node, blocks, pendingAnchors);
      }
    }

    function walkBlockNode(node, blocks, pendingAnchors) {
        if (!pendingAnchors) {
          pendingAnchors = [];
        }
        if (node.nodeType === 3) {
          var rawText = node.nodeValue;
          if (rawText && rawText.trim().length > 0) {
            var txtBlock = { k: 'paragraph', spans: [{ s: 'plain', t: rawText }] };
            consumeAnchors(txtBlock, pendingAnchors);
            blocks.push(txtBlock);
          }
          return;
        }
        if (node.nodeType !== 1) {
          return;
        }
        var tag = node.tagName.toLowerCase();
        var cls = classOf(node);

        // 页面导航噪音与工具条：直接丢弃。
        if (cls.indexOf('info-container') >= 0 ||
          cls.indexOf('page-options') >= 0 ||
          cls.indexOf('page-tags') >= 0 ||
          cls.indexOf('footnotes-footer') >= 0 ||
          // 「« SCP-001 | SCP-002 | SCP-003 »」前一篇/后一篇系列导航。
          cls.indexOf('footer-wikiwalk-nav') >= 0) {
          return;
        }
        if (tag === 'style' || tag === 'script' || tag === 'noscript') {
          return;
        }
        var ownDirect = directNodeAnchors(node);
        if (cls.indexOf('list-pages-box') >= 0) {
          var blockCountBefore = blocks.length;
          var imageCountBefore = out.images.length;
          mergeAnchors(pendingAnchors, ownDirect);
          walkBlocks(node, blocks, pendingAnchors);
          if (blocks.length > blockCountBefore || out.images.length > imageCountBefore) {
            addWarning('compat:list-pages-box-content');
          }
          return;
        }
        if (tag === 'ul' || tag === 'ol') {
          var listAnchors = [];
          mergeAnchors(listAnchors, ownDirect);
          var prevBlockLen = blocks.length;
          walkList(node, blocks, 0);
          if (blocks.length > prevBlockLen) {
            consumeAnchors(blocks[prevBlockLen], pendingAnchors, listAnchors);
          } else {
            mergeAnchors(pendingAnchors, listAnchors);
          }
          return;
        }
        if (tag === 'pre') {
          var preAnchors = [];
          collectInlineAnchors(node, preAnchors);
          var preText = node.textContent || '';
          if (preText.length > 0) {
            var preBlock = { k: 'paragraph', spans: [{ s: 'code', t: preText }] };
            consumeAnchors(preBlock, pendingAnchors, preAnchors);
            blocks.push(preBlock);
          } else {
            mergeAnchors(pendingAnchors, preAnchors);
          }
          addWarning('degraded:pre-layout');
          return;
        }
        if (tag === 'p') {
          var pAnchors = [];
          collectInlineAnchors(node, pAnchors);
          var pSpans = spansOf(node);
          if (pSpans.length > 0) {
            var pBlock = { k: 'paragraph', spans: pSpans };
            consumeAnchors(pBlock, pendingAnchors, pAnchors);
            blocks.push(pBlock);
          } else {
            mergeAnchors(pendingAnchors, pAnchors);
          }
          return;
        }
        if (/^h[1-6]$/.test(tag)) {
          var hAnchors = [];
          collectInlineAnchors(node, hAnchors);
          var hBlock = { k: 'heading', level: parseInt(tag.charAt(1), 10), spans: spansOf(node) };
          consumeAnchors(hBlock, pendingAnchors, hAnchors);
          blocks.push(hBlock);
          return;
        }
        if (tag === 'blockquote') {
          var quoteBlocks = [];
          var quotePending = [];
          walkBlocks(node, quoteBlocks, quotePending);
          if (quoteBlocks.length > 0 && quotePending.length > 0) {
            consumeAnchors(quoteBlocks[quoteBlocks.length - 1], quotePending);
          }
          var quoteBlock = { k: 'quote', blocks: quoteBlocks };
          consumeAnchors(quoteBlock, pendingAnchors, ownDirect);
          attachAnchors(quoteBlock, quotePending);
          blocks.push(quoteBlock);
          return;
        }
        if (tag === 'hr') {
          var hrBlock = { k: 'divider' };
          consumeAnchors(hrBlock, pendingAnchors, ownDirect);
          blocks.push(hrBlock);
          return;
        }
        if (tag === 'table') {
          var rows = [];
          var trs = node.querySelectorAll('tr');
          for (var r = 0; r < trs.length; r++) {
            var cells = [];
            var tds = trs[r].querySelectorAll('th,td');
            for (var c = 0; c < tds.length; c++) {
              var cellAnchors = [];
              collectInlineAnchors(tds[c], cellAnchors);
              var cellBlock = { k: 'cell', spans: spansOf(tds[c]) };
              attachAnchors(cellBlock, cellAnchors);
              cells.push(cellBlock);
            }
            rows.push({ k: 'row', blocks: cells });
          }
          var tableBlock = { k: 'table', blocks: rows };
          consumeAnchors(tableBlock, pendingAnchors, ownDirect);
          blocks.push(tableBlock);
          return;
        }
        if (tag === 'iframe') {
          var frameSrc = node.getAttribute('src') || '';
          if (frameSrc.indexOf('interwikiFrame') >= 0 || frameSrc.indexOf('styleFrame') >= 0) {
            return;
          }
          var embedBlock = { k: 'embed', src: frameSrc };
          consumeAnchors(embedBlock, pendingAnchors, ownDirect);
          blocks.push(embedBlock);
          return;
        }
        if (tag === 'div' && cls.indexOf('scp-image-block') >= 0) {
          var imgEl = node.querySelector('img');
          var captionEl = node.querySelector('.scp-image-caption');
          var caption = captionEl ? captionEl.textContent.trim() : '';
          if (imgEl) {
            recordImage(imgEl, caption);
          }
          return;
        }
        if (tag === 'div' && cls.indexOf('collapsible-block') >= 0) {
          var foldedDiv = node.querySelector(':scope > .collapsible-block-folded');
          var unfoldedDiv = node.querySelector(':scope > .collapsible-block-unfolded');
          var initiallyExpanded = !!(foldedDiv &&
            (foldedDiv.getAttribute('style') || '').toLowerCase().indexOf('display:none') >= 0 &&
            unfoldedDiv &&
            (unfoldedDiv.getAttribute('style') || '').toLowerCase().indexOf('display:none') < 0);
          var linkEl = node.querySelector('.collapsible-block-link');
          var contentEl = node.querySelector('.collapsible-block-content') || unfoldedDiv;
          var innerBlocks = [];
          var innerPending = [];
          if (contentEl) {
            walkBlocks(contentEl, innerBlocks, innerPending);
            if (innerBlocks.length > 0 && innerPending.length > 0) {
              consumeAnchors(innerBlocks[innerBlocks.length - 1], innerPending);
            }
          }
          var colBlock = {
            k: 'collapsible',
            title: linkEl ? linkEl.textContent.trim() : '',
            expanded: initiallyExpanded,
            blocks: innerBlocks
          };
          consumeAnchors(colBlock, pendingAnchors, ownDirect);
          attachAnchors(colBlock, innerPending);
          blocks.push(colBlock);
          return;
        }
        if (tag === 'div') {
          mergeAnchors(pendingAnchors, ownDirect);
          walkBlocks(node, blocks, pendingAnchors);
          return;
        }
        if (tag === 'audio' || tag === 'video' || tag === 'canvas' || tag === 'svg' ||
          tag === 'object' || tag === 'math') {
          var mediaAnchors = [];
          collectInlineAnchors(node, mediaAnchors);
          var beforeUnsupported = blocks.length;
          unsupportedFallback(node, tag, blocks);
          if (blocks.length > beforeUnsupported) {
            consumeAnchors(blocks[beforeUnsupported], pendingAnchors, mediaAnchors);
          } else {
            mergeAnchors(pendingAnchors, mediaAnchors);
          }
          return;
        }
        var fbAnchors = [];
        collectInlineAnchors(node, fbAnchors);
        var fallbackSpans = spansOf(node);
        if (fallbackSpans.length > 0) {
          var fbBlock = { k: 'paragraph', spans: fallbackSpans };
          consumeAnchors(fbBlock, pendingAnchors, fbAnchors);
          blocks.push(fbBlock);
        } else {
          mergeAnchors(pendingAnchors, fbAnchors);
        }
    }

    // `blocks.length > 0` 不能代表正文解析成功：空标题、空表格、空折叠块和
    // 单独的分隔线都会产生结构节点。这里按读者最终能看到的内容递归判断，
    // 同时允许以图片或有效嵌入为主体的页面。
    function spansHaveReadableContent(spans) {
      for (var index = 0; index < spans.length; index++) {
        var span = spans[index];
        if (span.s === 'footnote') {
          continue;
        }
        if (typeof span.t === 'string' && span.t.trim().length > 0) {
          return true;
        }
      }
      return false;
    }

    function blocksHaveReadableContent(blocks) {
      for (var index = 0; index < blocks.length; index++) {
        var block = blocks[index];
        if (block.k === 'divider') {
          continue;
        }
        if (block.k === 'embed') {
          if (typeof block.src === 'string' && block.src.trim().length > 0) {
            return true;
          }
          continue;
        }
        if (block.spans && spansHaveReadableContent(block.spans)) {
          return true;
        }
        if (block.blocks && blocksHaveReadableContent(block.blocks)) {
          return true;
        }
      }
      return false;
    }

    function imagesHaveReadableContent(images) {
      for (var index = 0; index < images.length; index++) {
        if (typeof images[index].src === 'string' && images[index].src.trim().length > 0) {
          return true;
        }
      }
      return false;
    }

    function isFootnoteBacklink(node) {
      if (!node || node.nodeType !== 1 || node.tagName.toLowerCase() !== 'a') {
        return false;
      }
      var onclick = (node.getAttribute('onclick') || '').toLowerCase();
      if (onclick.indexOf('scrolltoreference') >= 0) {
        return true;
      }
      var href = (node.getAttribute('href') || '').trim().toLowerCase();
      var label = (node.textContent || '').trim();
      return href === 'javascript:;' && /^\[?\d+\]?\.?$/.test(label);
    }

    function isFootnoteBlockTag(tag) {
      if (/^h[1-6]$/.test(tag)) {
        return true;
      }
      return tag === 'p' || tag === 'div' || tag === 'section' || tag === 'article' ||
        tag === 'blockquote' || tag === 'ul' || tag === 'ol' || tag === 'table' ||
        tag === 'pre' || tag === 'hr' || tag === 'iframe' || tag === 'audio' ||
        tag === 'video' || tag === 'canvas' || tag === 'svg' || tag === 'object' ||
        tag === 'math';
    }

    function parseFootnoteItem(item, itemBlocks) {
      var wrapper = document.createElement('span');
      var seenContent = false;
      var strippedBacklink = false;

      function flushInline() {
        if (!wrapper.firstChild) {
          return;
        }
        var pSpans = spansOf(wrapper);
        if (pSpans.length > 0) {
          itemBlocks.push({ k: 'paragraph', spans: pSpans });
        }
        while (wrapper.firstChild) {
          wrapper.removeChild(wrapper.firstChild);
        }
      }

      for (var node = item.firstChild; node; node = node.nextSibling) {
        if (!seenContent && node.nodeType === 3) {
          var raw = node.nodeValue || '';
          if (raw.trim().length === 0) {
            continue;
          }
          if (strippedBacklink) {
            raw = raw.replace(/^\s*[.．、:]\s*/, '');
            strippedBacklink = false;
            if (raw.trim().length === 0) {
              continue;
            }
          }
          seenContent = true;
          wrapper.appendChild(document.createTextNode(raw));
          continue;
        }
        if (node.nodeType !== 1) {
          continue;
        }
        var tag = node.tagName.toLowerCase();
        if (!seenContent && isFootnoteBacklink(node)) {
          strippedBacklink = true;
          continue;
        }
        if (!seenContent && tag === 'br') {
          continue;
        }
        if (isFootnoteBlockTag(tag)) {
          flushInline();
          strippedBacklink = false;
          seenContent = true;
          walkBlockNode(node, itemBlocks);
          continue;
        }
        strippedBacklink = false;
        if (tag === 'img' || tag === 'br' || readableTextOf(node).trim().length > 0) {
          seenContent = true;
        }
        wrapper.appendChild(node.cloneNode(true));
      }
      flushInline();
    }

    walkBlocks(pc, out.blocks);

    var pcLinks = pc.querySelectorAll('a[href]');
    for (var li = 0; li < pcLinks.length; li++) {
      var linkEl = pcLinks[li];
      if (linkEl.closest('.footer-wikiwalk-nav, .page-tags, .page-options, .info-container')) {
        continue;
      }
      var href = (linkEl.getAttribute('href') || '').trim();
      if (/\/offset\/\d+(?:[/?#]|$)/i.test(href)) {
        addWarning('interactive:listpages-offset');
        break;
      }
    }

    var styles = document.querySelectorAll('style');
    for (var si = 0; si < styles.length; si++) {
      var styleEl = styles[si];
      if ((styleEl.id || '').toLowerCase() === 'internal-style') {
        continue;
      }
      var cssText = styleEl.textContent || '';
      if (cssText.length < 4000) {
        continue;
      }
      var cssLow = cssText.toLowerCase();
      if (cssLow.indexOf('anom-bar') >= 0 ||
        cssLow.indexOf('bhl.scpwikicn') >= 0 ||
        cssLow.indexOf('black-highlighter') >= 0 ||
        (cssLow.indexOf('info-container') >= 0 && cssLow.indexOf('modal-wrapper') >= 0)) {
        continue;
      }
      if (cssLow.indexOf('@keyframes') >= 0 ||
        cssLow.indexOf('animation:') >= 0 ||
        cssLow.indexOf('grid-template') >= 0 ||
        cssLow.indexOf('clip-path') >= 0) {
        addWarning('format-screw:custom-css');
        break;
      }
    }

    var footnotesBox = pc.querySelector('.footnotes-footer');
    if (footnotesBox) {
      var footItems = footnotesBox.querySelectorAll('.footnote-footer');
      for (var f = 0; f < footItems.length; f++) {
        var item = footItems[f];
        var itemBlocks = [];
        parseFootnoteItem(item, itemBlocks);
        out.footnotes.push({
          id: (item.id || '').replace('footnote-', ''),
          index: f + 1,
          blocks: itemBlocks
        });
      }
    }
    if (out.title.length === 0) {
      throw new Error('page-title is empty');
    }
    if (!blocksHaveReadableContent(out.blocks) && !imagesHaveReadableContent(out.images)) {
      throw new Error('page-content contains no readable article body');
    }
    out.ok = true;
  } catch (e) {
    out.error = String((e && e.message) ? e.message : e);
  }
  return JSON.stringify(out);
}
