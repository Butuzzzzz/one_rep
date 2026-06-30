import os
import re
from bs4 import BeautifulSoup, NavigableString

ROOT = os.path.dirname(os.path.abspath(__file__))

ICONS = {
    'call': '{?Call.WebServerAddress}/images/icons/Call.png',
    'title': '{?Call.WebServerAddress}/images/icons/Title.png',
    'info': '{?Call.WebServerAddress}/images/icons/Info.png',
    'forward': '{?Call.WebServerAddress}/images/icons/forward.png',
}


def soup():
    return BeautifulSoup('', 'html.parser')


def header_rows(title_html, subtitle_html):
    rows = []
    s = soup()
    tr1 = s.new_tag('tr')
    td1 = s.new_tag('td')
    td1['style'] = "FONT-SIZE: 18px; FONT-WEIGHT: 600; PADDING-BOTTOM: 1px; PADDING-TOP: 12px; PADDING-LEFT: 20px; PADDING-RIGHT: 20px"
    td1['colSpan'] = '2'
    if title_html:
        td1.append(BeautifulSoup(title_html, 'html.parser'))
    tr1.append(td1)
    rows.append(tr1)
    if subtitle_html:
        tr2 = s.new_tag('tr')
        td2 = s.new_tag('td')
        td2['style'] = "FONT-SIZE: 15px; FONT-WEIGHT: 400; PADDING-BOTTOM: 12px; PADDING-TOP: 5px; PADDING-LEFT: 20px; PADDING-RIGHT: 20px"
        td2['colSpan'] = '2'
        td2.append(BeautifulSoup(subtitle_html, 'html.parser'))
        tr2.append(td2)
        rows.append(tr2)
    return rows


def make_icon_title_table(icon_src, title_html, header_color):
    s = soup()
    table = s.new_tag('table', role='presentation')
    table['cellSpacing'] = '0'
    table['cellPadding'] = '0'
    table['width'] = '100%'
    table['border'] = '0'
    table['style'] = "BORDER-COLLAPSE: collapse"
    tbody = s.new_tag('tbody')
    tr = s.new_tag('tr')

    td_icon = s.new_tag('td')
    td_icon['style'] = "PADDING-BOTTOM: 0px; PADDING-TOP: 0px; PADDING-LEFT: 0px; PADDING-RIGHT: 10px"
    td_icon['vAlign'] = 'middle'
    td_icon['width'] = '25'
    td_icon['align'] = 'left'
    img = s.new_tag('img', src=icon_src)
    img['style'] = "BORDER: 0px; DISPLAY: block"
    img['border'] = '0'
    img['alt'] = ''
    img['width'] = '20'
    img['height'] = '20'
    td_icon.append(img)
    tr.append(td_icon)

    td_title = s.new_tag('td')
    td_title['style'] = f"TEXT-TRANSFORM: uppercase; TEXT-INDENT: 1px; FONT-WEIGHT: 600; FONT-SIZE: 14px; COLOR: {header_color}; FONT-FAMILY: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif"
    td_title['vAlign'] = 'middle'
    td_title['align'] = 'left'
    if title_html:
        td_title.append(BeautifulSoup(title_html, 'html.parser'))
    tr.append(td_title)

    tbody.append(tr)
    table.append(tbody)
    return table


def make_divider(color):
    s = soup()
    div = s.new_tag('div')
    div['style'] = f"FONT-SIZE: 3px; PADDING-BOTTOM: 3px; BORDER-BOTTOM: {color} 2px solid"
    div.append(NavigableString('\xa0'))
    return div


def make_open_link_card(href):
    s = soup()
    table = s.new_tag('table', role='presentation')
    table['style'] = "BACKGROUND-COLOR: #f8fafc; BORDER-RADIUS: 5px; BORDER: #e2e8f0 1px solid; FONT-SIZE: 14px; BORDER-COLLAPSE: separate; BORDER-SPACING: 1px; TEXT-DECORATION: none"
    table['bgColor'] = '#f8fafc'
    table['cellSpacing'] = '1'
    table['cellPadding'] = '5'
    table['width'] = '100%'
    table['border'] = '0'
    table['class'] = 'card-info-shadow'
    tbody = s.new_tag('tbody')
    tr = s.new_tag('tr')

    def cell(contents):
        tr.append(contents)

    # icon
    td1 = s.new_tag('td')
    td1['style'] = "PADDING-BOTTOM: 0px; PADDING-TOP: 0px; PADDING-LEFT: 12px; PADDING-RIGHT: 0px"
    td1['vAlign'] = 'middle'
    td1['width'] = '20'
    td1['align'] = 'left'
    a1 = s.new_tag('a', href=href)
    a1['style'] = "CURSOR: pointer; TEXT-DECORATION: none; BORDER: 0px"
    img1 = s.new_tag('img', src=ICONS['call'])
    img1['style'] = "BORDER: 0px; DISPLAY: block"
    img1['border'] = '0'
    img1['alt'] = ''
    img1['width'] = '20'
    img1['height'] = '20'
    a1.append(img1)
    td1.append(a1)
    tr.append(td1)

    # text
    td2 = s.new_tag('td')
    td2['style'] = "FONT-SIZE: 16px; FONT-FAMILY: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; WIDTH: 1%; WHITE-SPACE: nowrap; FONT-WEIGHT: 600"
    td2['vAlign'] = 'middle'
    td2['width'] = '1%'
    td2['noWrap'] = None
    td2['align'] = 'left'
    a2 = s.new_tag('a', href=href)
    a2['style'] = "CURSOR: pointer; TEXT-DECORATION: none; BORDER: 0px"
    span2 = s.new_tag('span')
    span2['style'] = "TEXT-DECORATION: none; COLOR: #2a5298"
    span2.append(NavigableString('Заявка №{?Call.NumberString}'))
    a2.append(span2)
    td2.append(a2)
    tr.append(td2)

    # open text
    td3 = s.new_tag('td')
    td3['style'] = "FONT-SIZE: 15px; FONT-FAMILY: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; FONT-WEIGHT: 400; COLOR: #1a87e7; PADDING-RIGHT: 2px"
    td3['width'] = '100%'
    td3['align'] = 'right'
    a3 = s.new_tag('a', href=href)
    a3['class'] = 'open-link'
    a3['style'] = "CURSOR: pointer; TEXT-DECORATION: none; BORDER: 0px"
    span3 = s.new_tag('span')
    span3['style'] = "TEXT-DECORATION: none; COLOR: #1a87e7"
    span3.append(NavigableString('открыть'))
    a3.append(span3)
    td3.append(a3)
    tr.append(td3)

    # forward icon
    td4 = s.new_tag('td')
    td4['style'] = "PADDING-BOTTOM: 0px; PADDING-TOP: 2px; PADDING-LEFT: 0px; PADDING-RIGHT: 10px"
    td4['align'] = 'right'
    a4 = s.new_tag('a', href=href)
    a4['style'] = "CURSOR: pointer; TEXT-DECORATION: none; BORDER: 0px"
    img4 = s.new_tag('img', src=ICONS['forward'])
    img4['style'] = "BORDER: 0px; DISPLAY: block"
    img4['border'] = '0'
    img4['alt'] = 'Открыть заявку'
    img4['width'] = '22'
    img4['height'] = '24'
    a4.append(img4)
    td4.append(a4)
    tr.append(td4)

    tbody.append(tr)
    table.append(tbody)
    return table


def card_kind(table):
    classes = ' '.join(table.get('class') or [])
    style = table.get('style') or ''
    if 'td-grade-block' in classes or 'table-grade' in classes:
        return 'grade'
    if 'card-green' in classes:
        return 'green'
    if 'card-red' in classes or 'table-red-block' in classes:
        return 'red'
    if 'table-yellow-block' in classes or '#fcf4d4' in style or '#fcfce3' in style:
        return 'yellow'
    return 'blue'


def strip_divider(div):
    cls = ' '.join(div.get('class') or [])
    if 'blue' in cls:
        div['style'] = "FONT-SIZE: 3px; PADDING-BOTTOM: 3px; BORDER-BOTTOM: #b3d1ff 2px solid"
    elif 'red' in cls:
        div['style'] = "FONT-SIZE: 3px; PADDING-BOTTOM: 3px; BORDER-BOTTOM: #ffb3b3 2px solid"
    elif 'green' in cls:
        div['style'] = "FONT-SIZE: 3px; PADDING-BOTTOM: 3px; BORDER-BOTTOM: #c8e6c9 2px solid"
    else:
        div['style'] = "FONT-SIZE: 3px; PADDING-BOTTOM: 3px; BORDER-BOTTOM: #dadada 1px solid"
    if 'class' in div.attrs:
        del div.attrs['class']


def make_card(table):
    kind = card_kind(table)
    s = soup()
    outer = s.new_tag('table', role='presentation')
    outer['cellSpacing'] = '0'
    outer['cellPadding'] = '0'
    outer['width'] = '100%'
    outer['border'] = '0'
    outer['style'] = "BORDER-RADIUS: 5px; BORDER-COLLAPSE: separate; BORDER-SPACING: 0px; FONT-SIZE: 14px"

    if kind == 'red':
        outer['class'] = 'card-cancel-gradient'
        outer['bgColor'] = '#fff8f8'
        outer['style'] += "; BACKGROUND-COLOR: #fff8f8; BORDER: #ffb3b3 1px solid"
        header_color = '#d63333'
        divider_color = '#ffb3b3'
        default_icon = ICONS['info']
    elif kind == 'green':
        outer['class'] = 'card-success-gradient'
        outer['bgColor'] = '#f9fff7'
        outer['style'] += "; BACKGROUND-COLOR: #f9fff7; BORDER: #c3e2ca 1px solid"
        header_color = '#1e8a1e'
        divider_color = '#c8e6c9'
        default_icon = '{?Call.WebServerAddress}/images/icons/Решение.png'
    elif kind == 'yellow':
        outer['class'] = 'card-warning-yellow'
        outer['bgColor'] = '#fffdf5'
        outer['style'] += "; BACKGROUND-COLOR: #fffdf5; BORDER: #f5e6a3 1px solid"
        header_color = '#b58a00'
        divider_color = '#f5e6a3'
        default_icon = ICONS['info']
    else:
        outer['class'] = 'card-info-shadow'
        outer['bgColor'] = '#f8fafc'
        outer['style'] += "; BACKGROUND-COLOR: #f8fafc; BORDER: #e2e8f0 1px solid"
        header_color = '#2a5298'
        divider_color = '#b3d1ff'
        default_icon = ICONS['info']

    tbody = s.new_tag('tbody')

    rows = table.find_all('tr', recursive=False)
    if not rows:
        rows = table.find_all('tr')
    header_row = rows[0] if rows else None
    body_rows = rows[1:] if len(rows) > 1 else []

    icon_src = None
    title_html = ''
    if header_row:
        header_td = header_row.find('td', recursive=False)
        if not header_td:
            header_td = header_row.find('td')
        if header_td:
            # remove divider divs first
            for d in list(header_td.find_all('div', class_=lambda x: x and 'divider' in ' '.join(x))):
                d.decompose()
            # look for nested icon table
            nested = header_td.find('table', recursive=False)
            if nested and nested.find('img'):
                img = nested.find('img')
                icon_src = img.get('src')
                tds = nested.find_all('td')
                if len(tds) >= 2:
                    title_html = ''.join(str(c) for c in tds[1].contents).strip()
                nested.decompose()
            else:
                img = header_td.find('img')
                if img:
                    icon_src = img.get('src')
                    img.decompose()
            if not title_html:
                title_html = ''.join(str(c) for c in header_td.contents).strip()
            title_html = re.sub(r'\s+', ' ', title_html).strip()

    if not icon_src:
        lt = title_html.lower()
        if 'решение' in lt:
            icon_src = '{?Call.WebServerAddress}/images/icons/Решение.png'
        elif 'заявка' in lt or '{?Call.CallSummaryName}' in title_html:
            icon_src = ICONS['title']
        else:
            icon_src = default_icon
    if not title_html:
        title_html = '&nbsp;'

    tr_h = s.new_tag('tr')
    td_h = s.new_tag('td')
    td_h['style'] = "PADDING-TOP: 10px; PADDING-LEFT: 15px; PADDING-RIGHT: 15px"
    td_h.append(make_icon_title_table(icon_src, title_html, header_color))
    td_h.append(make_divider(divider_color))
    tr_h.append(td_h)
    tbody.append(tr_h)

    for br in body_rows:
        tds = br.find_all('td', recursive=False)
        if not tds:
            tds = br.find_all('td')
        for body_td in tds:
            tr_b = s.new_tag('tr')
            td_b = s.new_tag('td')
            td_b['style'] = "TEXT-INDENT: 1px; FONT-SIZE: 14px; COLOR: #3f3f3f; LINE-HEIGHT: 1.4; PADDING-TOP: 8px; PADDING-BOTTOM: 11px; PADDING-LEFT: 15px; PADDING-RIGHT: 15px"
            # convert divider classes
            for d in body_td.find_all('div', class_=lambda x: x and 'divider' in ' '.join(x)):
                strip_divider(d)
            # remove negative margins on div-message to avoid broken layout
            for d in body_td.find_all('div', class_=lambda x: x and 'div-message' in ' '.join(x)):
                st = d.get('style') or ''
                st = re.sub(r'margin-left\s*:\s*[^;]+;?', '', st, flags=re.I)
                st = re.sub(r'text-indent\s*:\s*[^;]+;?', '', st, flags=re.I)
                st = st.strip(' ;')
                d['style'] = st if st else None
                if 'class' in d.attrs:
                    del d.attrs['class']
            for c in list(body_td.contents):
                td_b.append(c)
            tr_b.append(td_b)
            tbody.append(tr_b)

    outer.append(tbody)
    return outer


def make_grade_block(table):
    s = soup()
    outer = s.new_tag('table', role='presentation')
    outer['style'] = "BACKGROUND-COLOR: #f8fafc; BORDER-RADIUS: 5px; BORDER: #e2e8f0 1px solid; BORDER-COLLAPSE: separate; BORDER-SPACING: 0px"
    outer['bgColor'] = '#f8fafc'
    outer['cellSpacing'] = '0'
    outer['cellPadding'] = '0'
    outer['width'] = '100%'
    outer['border'] = '0'
    outer['class'] = 'card-info-shadow'
    tbody = s.new_tag('tbody')
    tr = s.new_tag('tr')
    td = s.new_tag('td')
    td['style'] = "PADDING: 10px 25px; TEXT-ALIGN: center"
    td['align'] = 'center'
    # convert divider classes if any
    for d in table.find_all('div', class_=lambda x: x and 'divider' in ' '.join(x)):
        strip_divider(d)
    for c in list(table.contents):
        td.append(c)
    tr.append(td)
    tbody.append(tr)
    outer.append(tbody)
    return outer


def make_image_button(table):
    """Preserve a single-image button table (e.g. button_recover.png)."""
    s = soup()
    a = table.find('a')
    img = table.find('img')
    href = a['href'] if a and a.get('href') else '#'
    src = img['src'] if img and img.get('src') else ''
    alt = img.get('alt') or ''
    outer = s.new_tag('table', role='presentation')
    outer['cellSpacing'] = '0'
    outer['cellPadding'] = '0'
    outer['width'] = '100%'
    outer['border'] = '0'
    tbody = s.new_tag('tbody')
    tr = s.new_tag('tr')
    td = s.new_tag('td')
    td['align'] = 'center'
    td['style'] = "PADDING: 0px; TEXT-ALIGN: center"
    link = s.new_tag('a', href=href)
    link['style'] = "BORDER: 0px; TEXT-DECORATION: none"
    image = s.new_tag('img', src=src)
    image['alt'] = alt
    image['border'] = '0'
    image['style'] = "BORDER: 0px; DISPLAY: block; MARGIN: 0 auto"
    link.append(image)
    td.append(link)
    tr.append(td)
    tbody.append(tr)
    outer.append(tbody)
    return outer


def is_button_table(table):
    return bool(table.find('img', src=lambda x: x and 'call_mini' in x))


def is_call_info_table(table):
    return bool(table.find('img', src=lambda x: x and 'Call.png' in x) and
                table.find('a', href=lambda x: x and 'callNumber' in x))


def is_image_only_table(table):
    if table.find('table'):
        return False
    imgs = table.find_all('img')
    txts = table.get_text(strip=True)
    return len(imgs) == 1 and not txts


def extract_call_href(table):
    a = table.find('a', href=lambda x: x and 'callNumber' in x)
    if a:
        return a['href']
    return '{?Call.WebServerAddress}?callNumber={?Call.NumberString}'


def convert_body_item(item, call_href):
    if isinstance(item, NavigableString):
        txt = str(item).strip()
        if txt:
            s = soup()
            div = s.new_tag('div')
            div['style'] = "FONT-SIZE: 15px; LINE-HEIGHT: 15px"
            div.append(NavigableString('\xa0'))
            return div
        return None
    name = getattr(item, 'name', None)
    if name == 'div':
        cls = ' '.join(item.get('class') or [])
        if 'sign' in cls:
            s = soup()
            div = s.new_tag('div')
            div['style'] = "PADDING-LEFT: 10px; FONT-SIZE: 13px; COLOR: #2a5298; LINE-HEIGHT: 1.4"
            for c in list(item.contents):
                div.append(c)
            return div
        if 'break' in cls or not item.get_text(strip=True):
            s = soup()
            div = s.new_tag('div')
            div['style'] = "FONT-SIZE: 15px; LINE-HEIGHT: 15px"
            div.append(NavigableString('\xa0'))
            return div
        return item
    if name == 'table':
        if is_button_table(item):
            return make_open_link_card(extract_call_href(item))
        if is_call_info_table(item):
            return make_open_link_card(extract_call_href(item))
        if is_image_only_table(item):
            return make_image_button(item)
        if card_kind(item) == 'grade':
            return make_grade_block(item)
        return make_card(item)
    return None


def build_html(title, header_title, header_subtitle, header_bg, body_items):
    s = soup()
    html = s.new_tag('html')
    head = s.new_tag('head')
    title_tag = s.new_tag('title')
    title_tag.append(NavigableString(title))
    head.append(title_tag)

    meta1 = s.new_tag('meta', content="text/html; charset=utf-8")
    meta1['http-equiv'] = 'Content-Type'
    head.append(meta1)
    meta2 = s.new_tag('meta', content="width=device-width, initial-scale=1.0")
    meta2['name'] = 'viewport'
    head.append(meta2)

    style = s.new_tag('style')
    style.append(NavigableString("""\n  .title-gradient { background: linear-gradient(135deg, #2a5298 0%, #1e3c72 100%) !important; }\n  .card-cancel-gradient { background: linear-gradient(135deg, #fff8f8 0%, #fff0f0 100%) !important; box-shadow: 0 4px 12px rgba(214, 51, 51, 0.10) !important; }\n  .card-success-gradient { background: linear-gradient(135deg, #f9fff7 0%, #f0fff0 100%) !important; box-shadow: 0 4px 12px rgba(30, 138, 30, 0.10) !important; }\n  .card-warning-yellow { background: linear-gradient(135deg, #fffdf5 0%, #fff8e1 100%) !important; box-shadow: 0 4px 12px rgba(181, 138, 0, 0.10) !important; }\n  .card-info-shadow { box-shadow: 0 4px 12px rgba(42, 82, 152, 0.10) !important; }\n  .open-link:hover span { text-decoration: underline !important; }\n  @media only screen and (max-width: 660px) {\n   .content-wrapper { width: 100% !important; }\n   .main-td { padding-left: 20px !important; padding-right: 20px !important; }\n   .title-td table td { padding-left: 15px !important; padding-right: 15px !important; }\n  }\n"""))
    head.append(style)
    html.append(head)

    body = s.new_tag('body')
    body['style'] = "MARGIN: 0px; PADDING: 0px; WIDTH: 100%; BACKGROUND-COLOR: #f5f5f5; FONT-FAMILY: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;"

    outer = s.new_tag('table', role='presentation')
    outer['style'] = "BACKGROUND-COLOR: #f5f5f5; BORDER-COLLAPSE: collapse"
    outer['cellSpacing'] = '0'
    outer['cellPadding'] = '0'
    outer['width'] = '100%'
    outer['border'] = '0'
    outer_tbody = s.new_tag('tbody')
    outer_tr = s.new_tag('tr')
    outer_td = s.new_tag('td')
    outer_td['style'] = "PADDING-BOTTOM: 30px; PADDING-TOP: 30px; PADDING-LEFT: 10px; PADDING-RIGHT: 10px"
    outer_td['vAlign'] = 'top'
    outer_td['align'] = 'center'

    wrapper = s.new_tag('table', role='presentation')
    wrapper['class'] = 'content-wrapper'
    wrapper['style'] = "BORDER: #dddddd 1px solid; WIDTH: 650px; BACKGROUND-COLOR: #ffffff; BORDER-COLLAPSE: collapse; TEXT-ALIGN: left; BORDER-RADIUS: 5px; OVERFLOW: hidden"
    wrapper['cellSpacing'] = '0'
    wrapper['cellPadding'] = '0'
    wrapper['width'] = '650'
    wrapper['border'] = '0'
    wrap_tbody = s.new_tag('tbody')

    # header
    tr_h = s.new_tag('tr')
    td_h = s.new_tag('td')
    td_h['class'] = 'title-td title-gradient'
    td_h['style'] = f"COLOR: #ffffff; FONT-FAMILY: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; BACKGROUND-COLOR: {header_bg}; PADDING: 0px; BORDER-RADIUS: 5px 5px 0px 0px"
    td_h['bgColor'] = header_bg
    inner_h = s.new_tag('table', role='presentation')
    inner_h['style'] = "FONT-FAMILY: 'Segoe UI', Tahoma, Geneva, sans-serif; COLOR: #ffffff; BORDER-COLLAPSE: collapse"
    inner_h['cellSpacing'] = '0'
    inner_h['cellPadding'] = '0'
    inner_h['border'] = '0'
    inner_h_tbody = s.new_tag('tbody')
    for hr in header_rows(header_title, header_subtitle):
        inner_h_tbody.append(hr)
    inner_h.append(inner_h_tbody)
    td_h.append(inner_h)
    tr_h.append(td_h)
    wrap_tbody.append(tr_h)

    # main
    tr_m = s.new_tag('tr')
    td_m = s.new_tag('td')
    td_m['class'] = 'main-td'
    td_m['style'] = "PADDING-BOTTOM: 10px; PADDING-TOP: 20px; PADDING-LEFT: 30px; PADDING-RIGHT: 30px"

    inner_m = s.new_tag('table', role='presentation')
    inner_m['style'] = "BORDER-COLLAPSE: collapse"
    inner_m['cellSpacing'] = '0'
    inner_m['cellPadding'] = '0'
    inner_m['width'] = '100%'
    inner_m['border'] = '0'
    inner_m_tbody = s.new_tag('tbody')
    inner_m_tr = s.new_tag('tr')
    inner_m_td = s.new_tag('td')
    for item in body_items:
        inner_m_td.append(item)
    inner_m_tr.append(inner_m_td)
    inner_m_tbody.append(inner_m_tr)
    inner_m.append(inner_m_tbody)
    td_m.append(inner_m)
    tr_m.append(td_m)
    wrap_tbody.append(tr_m)

    # footer
    tr_f = s.new_tag('tr')
    td_f = s.new_tag('td')
    td_f['style'] = "FONT-SIZE: 12px; BORDER-TOP: #dddddd 1px solid; COLOR: #888888; PADDING: 15px; BACKGROUND-COLOR: #f8f8f8; TEXT-ALIGN: center; BORDER-RADIUS: 0px 0px 5px 5px"
    td_f['bgColor'] = '#f8f8f8'
    td_f['align'] = 'center'
    div_f = s.new_tag('div')
    div_f.append(NavigableString('© 2026 Служба поддержки. Все права защищены.'))
    td_f.append(div_f)
    tr_f.append(td_f)
    wrap_tbody.append(tr_f)

    wrapper.append(wrap_tbody)
    outer_td.append(wrapper)
    outer_tr.append(outer_td)
    outer_tbody.append(outer_tr)
    outer.append(outer_tbody)
    body.append(outer)
    html.append(body)
    s.append(html)
    return s


def parse_header(soup):
    title = soup.title.string.strip() if soup.title and soup.title.string else ''
    title_td = None
    for td in soup.find_all('td'):
        cls = ' '.join(td.get('class') or [])
        if 'title-td' in cls:
            title_td = td
            break
    if not title_td:
        for td in soup.find_all('td'):
            style = td.get('style') or ''
            if '#2a5298' in style:
                title_td = td
                break

    header_bg = '#2a5298'
    header_title = title
    header_subtitle = ''
    if title_td:
        style = title_td.get('style') or ''
        m = re.search(r'background-color\s*:\s*(#[0-9a-fA-F]{6})', style, re.I)
        if m:
            header_bg = m.group(1).lower()
        # inner table variant
        inner_table = title_td.find('table')
        if inner_table:
            rows = inner_table.find_all('tr', recursive=False)
            if not rows:
                rows = inner_table.find_all('tr')
            if rows:
                first_td = rows[0].find('td', recursive=False)
                if not first_td:
                    first_td = rows[0].find('td')
                header_title = ''.join(str(c) for c in first_td.contents).strip() if first_td else title
                header_title = re.sub(r'\s+', ' ', header_title).strip()
                if len(rows) > 1:
                    second_td = rows[1].find('td', recursive=False)
                    if not second_td:
                        second_td = rows[1].find('td')
                    header_subtitle = ''.join(str(c) for c in second_td.contents).strip() if second_td else ''
                    header_subtitle = re.sub(r'\s+', ' ', header_subtitle).strip()
        else:
            divs = [c for c in title_td.children if getattr(c, 'name', None) == 'div']
            if divs:
                header_title = ''.join(str(c) for c in divs[0].contents).strip()
                header_title = re.sub(r'\s+', ' ', header_title).strip()
                if len(divs) > 1:
                    header_subtitle = ''.join(str(c) for c in divs[1].contents).strip()
                    header_subtitle = re.sub(r'\s+', ' ', header_subtitle).strip()
            else:
                header_title = ''.join(str(c) for c in title_td.contents).strip()
                header_title = re.sub(r'\s+', ' ', header_title).strip()
    return title, header_title, header_subtitle, header_bg


def find_body_container(soup):
    candidates = []
    for td in soup.find_all('td'):
        style = td.get('style') or ''
        if 'PADDING-LEFT: 30px' in style and 'PADDING-RIGHT: 30px' in style:
            candidates.append(td)
    if not candidates:
        for td in soup.find_all('td'):
            style = td.get('style') or ''
            if 'PADDING-TOP: 20px' in style:
                candidates.append(td)
    if not candidates:
        return None
    for td in reversed(candidates):
        if td.find('table', class_=lambda x: x and ('card' in ' '.join(x) or 'table-' in ' '.join(x))):
            return td
    return candidates[-1]


def extract_body_items(body_td):
    items = []
    wrapper = body_td.find('table', recursive=False)
    if wrapper and wrapper.get('width') == '100%' and len(body_td.find_all('table', recursive=False)) == 1:
        container = wrapper.find('td')
    else:
        container = body_td
    if not container:
        container = body_td

    call_href = '{?Call.WebServerAddress}?callNumber={?Call.NumberString}'
    for child in container.children:
        if getattr(child, 'name', None) == 'table' and (is_button_table(child) or is_call_info_table(child)):
            call_href = extract_call_href(child)
            break

    # If first table is a button table containing a grade table (Call Grade), split them
    first = next((c for c in container.children if getattr(c, 'name', None) == 'table'), None)
    extra_items = []
    if first and is_button_table(first):
        # find any nested tables in the button table besides the button itself
        nested_tables = [t for t in first.find_all('table') if not is_button_table(t)]
        if nested_tables:
            for nt in nested_tables:
                extra_items.append(nt.extract())

    for child in list(container.children):
        converted = convert_body_item(child, call_href)
        if converted is not None:
            items.append(converted)
    # Insert extra items after the first item if needed
    if extra_items and items:
        pos = 1
        for ex in extra_items:
            conv = convert_body_item(ex, call_href)
            if conv:
                items.insert(pos, conv)
                pos += 1
    return items, call_href


def uppercase_html(html):
    # Uppercase tag names
    html = re.sub(r'</?([a-zA-Z][a-zA-Z0-9]*)', lambda m: m.group(0).upper(), html)
    # Uppercase known attributes (preserve values)
    attrs = ['cellspacing', 'cellpadding', 'bgcolor', 'valign', 'align', 'border',
             'width', 'colspan', 'nowrap', 'role', 'class', 'style', 'src', 'alt',
             'href', 'content', 'http-equiv', 'name', 'height']
    for attr in attrs:
        html = re.sub(r'\b' + attr + r'\s*=', attr.upper() + '=', html, flags=re.I)
    return html


def check_balance(html):
    counts = {}
    for tag in ['table', 'tr', 'td', 'div']:
        open_count = len(re.findall(r'<' + tag + r'\b', html, re.I))
        close_count = len(re.findall(r'</' + tag + r'>', html, re.I))
        counts[tag] = (open_count, close_count)
    return counts


def process_file(path, report):
    fname = os.path.basename(path)
    with open(path, 'r', encoding='utf-8') as f:
        original = f.read()
    soup_orig = BeautifulSoup(original, 'html.parser')
    title, header_title, header_subtitle, header_bg = parse_header(soup_orig)
    body_td = find_body_container(soup_orig)
    if not body_td:
        report.append(f'{fname}: ОШИБКА — не найден контейнер тела')
        return False
    items, _ = extract_body_items(body_td)
    new_soup = build_html(title, header_title, header_subtitle, header_bg, items)
    # Add role=presentation to all tables missing it
    for table in new_soup.find_all('table'):
        if not table.get('role'):
            table['role'] = 'presentation'
    out = str(new_soup)
    out = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">\n' + out
    out = uppercase_html(out)
    bal = check_balance(out)
    problems = [t for t, (o, c) in bal.items() if o != c]
    if problems:
        report.append(f'{fname}: ОШИБКА баланса тегов {problems}')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(out)
    report.append(f'{fname}: обновлён' + (f' (исправлен баланс: {problems})' if problems else ''))
    return True


def main():
    files = [f for f in os.listdir(ROOT) if f.lower().endswith('.html')]
    files.sort()
    report = []
    for fname in files:
        if fname.lower() == 'call cancel (client).html':
            # verify only
            with open(os.path.join(ROOT, fname), 'r', encoding='utf-8') as f:
                html = f.read()
            bal = check_balance(html)
            problems = [t for t, (o, c) in bal.items() if o != c]
            report.append(f'{fname}: шаблон не изменён' + (f' (баланс: {problems})' if problems else ''))
            continue
        process_file(os.path.join(ROOT, fname), report)
    for line in report:
        print(line)


if __name__ == '__main__':
    main()
