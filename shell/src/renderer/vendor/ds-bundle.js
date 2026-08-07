/* @ds-bundle: {"format":4,"namespace":"SymbioteOSDesignSystem_5d2af6","components":[{"name":"Badge","sourcePath":"components/core/Badge/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button/Button.jsx"},{"name":"Icon","sourcePath":"components/core/Icon/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton/IconButton.jsx"},{"name":"Input","sourcePath":"components/core/Input/Input.jsx"},{"name":"Panel","sourcePath":"components/core/Panel/Panel.jsx"},{"name":"ProgressBar","sourcePath":"components/core/ProgressBar/ProgressBar.jsx"},{"name":"RadialGauge","sourcePath":"components/core/RadialGauge/RadialGauge.jsx"},{"name":"Switch","sourcePath":"components/core/Switch/Switch.jsx"},{"name":"Tabs","sourcePath":"components/core/Tabs/Tabs.jsx"},{"name":"Tooltip","sourcePath":"components/core/Tooltip/Tooltip.jsx"}],"sourceHashes":{"components/core/Badge/Badge.jsx":"073ce08db317","components/core/Button/Button.jsx":"38d7486470dc","components/core/Icon/Icon.jsx":"2633d78ad986","components/core/IconButton/IconButton.jsx":"4dd83cdda435","components/core/Input/Input.jsx":"45dcab474af2","components/core/Panel/Panel.jsx":"38a1ad381588","components/core/ProgressBar/ProgressBar.jsx":"868c59fb73f2","components/core/RadialGauge/RadialGauge.jsx":"9f5c609c0973","components/core/Switch/Switch.jsx":"91bf06108f65","components/core/Tabs/Tabs.jsx":"1793a24939bb","components/core/Tooltip/Tooltip.jsx":"a54841a49282","ui_kits/dashboard/ActivityFeed.jsx":"b2d2881c03a2","ui_kits/dashboard/Dashboard.jsx":"0f34596fd480","ui_kits/dashboard/Hologram.jsx":"369e96fce4c8","ui_kits/dashboard/MicroReadout.jsx":"bc2327d1325d","ui_kits/dashboard/ScanThumbs.jsx":"77cf7bcb34dc","ui_kits/dashboard/Waveform.jsx":"2c1fdcdcd266","ui_kits/desktop/Desktop.jsx":"cd6cb17f68f1","ui_kits/desktop/Dock.jsx":"214c625884b7","ui_kits/desktop/FileManagerApp.jsx":"24d43fa897e3","ui_kits/desktop/NetworkApp.jsx":"73cb2778f950","ui_kits/desktop/OS.jsx":"135b57a5740b","ui_kits/desktop/TerminalApp.jsx":"4ddd2f977c12","ui_kits/desktop/ToolsApp.jsx":"a021118706db","ui_kits/desktop/TopBar.jsx":"bc41eba33d71","ui_kits/desktop/WindowFrame.jsx":"fd719a8c8a4b"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.SymbioteOSDesignSystem_5d2af6 = window.SymbioteOSDesignSystem_5d2af6 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Badge/Badge.jsx
try { (() => {
const sevColor = {
  ok: 'var(--accent)',
  warning: 'var(--blue-bright)',
  critical: 'var(--state-critical)',
  neutral: 'var(--grey-text)'
};
function Badge(props) {
  const {
    children,
    severity = 'ok',
    pulse = false
  } = props;
  const color = sevColor[severity] || sevColor.ok;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-xs)',
      letterSpacing: 'var(--tracking-wide)',
      textTransform: 'uppercase',
      color,
      border: `1px solid ${color}`,
      padding: '3px 8px',
      background: 'rgba(0,0,0,0.3)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: '5px',
      height: '5px',
      borderRadius: '50%',
      background: color,
      boxShadow: `0 0 6px ${color}`,
      animation: pulse ? 'symbiote-pulse var(--dur-pulse) ease-in-out infinite' : 'none'
    }
  }), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon/Icon.jsx
try { (() => {
function Icon(props) {
  const {
    name,
    size = 16,
    strokeWidth = 1.75,
    style
  } = props;
  const ref = React.useRef(null);
  React.useEffect(() => {
    if (window.lucide && ref.current) {
      ref.current.innerHTML = '';
      const el = document.createElement('i');
      el.setAttribute('data-lucide', name);
      ref.current.appendChild(el);
      window.lucide.createIcons({
        attrs: {
          width: size,
          height: size,
          'stroke-width': strokeWidth
        }
      });
    }
  }, [name, size, strokeWidth]);
  return /*#__PURE__*/React.createElement("span", {
    ref: ref,
    style: {
      display: 'inline-flex',
      color: 'inherit',
      lineHeight: 0,
      ...style
    }
  });
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Button/Button.jsx
try { (() => {
const sizeMap = {
  sm: {
    pad: '6px 14px',
    font: 'var(--text-xs)'
  },
  md: {
    pad: '9px 20px',
    font: 'var(--text-sm)'
  }
};
const variantColor = {
  primary: 'var(--accent)',
  ghost: 'var(--grey-text)',
  danger: 'var(--state-critical)'
};
function Brackets({
  color
}) {
  const t = 'var(--bracket-thickness)';
  const base = {
    position: 'absolute',
    width: 'var(--bracket-size)',
    height: 'var(--bracket-size)',
    pointerEvents: 'none'
  };
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      top: -1,
      left: -1,
      borderTop: `${t} solid ${color}`,
      borderLeft: `${t} solid ${color}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      top: -1,
      right: -1,
      borderTop: `${t} solid ${color}`,
      borderRight: `${t} solid ${color}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      bottom: -1,
      left: -1,
      borderBottom: `${t} solid ${color}`,
      borderLeft: `${t} solid ${color}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      bottom: -1,
      right: -1,
      borderBottom: `${t} solid ${color}`,
      borderRight: `${t} solid ${color}`
    }
  }));
}
function Button(props) {
  const {
    children,
    variant = 'primary',
    size = 'md',
    disabled = false,
    onClick,
    icon
  } = props;
  const [hover, setHover] = React.useState(false);
  const color = variantColor[variant] || variantColor.primary;
  const s = sizeMap[size] || sizeMap.md;
  return /*#__PURE__*/React.createElement("button", {
    onClick: disabled ? undefined : onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    disabled: disabled,
    style: {
      position: 'relative',
      fontFamily: 'var(--font-mono)',
      fontSize: s.font,
      letterSpacing: 'var(--tracking-wider)',
      textTransform: 'uppercase',
      fontWeight: 'var(--weight-medium)',
      padding: s.pad,
      display: 'inline-flex',
      alignItems: 'center',
      gap: 'var(--space-3)',
      background: hover && !disabled ? 'var(--blue-faint)' : 'transparent',
      border: `1px solid ${disabled ? 'var(--grey-line)' : color}`,
      color: disabled ? 'var(--text-muted)' : color,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? 0.4 : 1,
      boxShadow: hover && !disabled ? variant === 'danger' ? 'var(--glow-critical)' : 'var(--glow-sm)' : 'none',
      transition: 'all var(--dur-fast) var(--ease-symbiote)'
    }
  }, /*#__PURE__*/React.createElement(Brackets, {
    color: disabled ? 'var(--grey-line)' : color
  }), icon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 14
  }), children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton/IconButton.jsx
try { (() => {
function IconButton(props) {
  const {
    children,
    active = false,
    label,
    onClick
  } = props;
  const [hover, setHover] = React.useState(false);
  const on = active || hover;
  return /*#__PURE__*/React.createElement("button", {
    title: label,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      width: '30px',
      height: '30px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: on ? 'var(--blue-faint)' : 'transparent',
      border: `1px solid ${on ? 'var(--accent)' : 'var(--grey-line)'}`,
      color: on ? 'var(--accent)' : 'var(--text-muted)',
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-md)',
      boxShadow: on ? 'var(--glow-xs)' : 'none',
      cursor: 'pointer',
      transition: 'all var(--dur-fast) var(--ease-symbiote)'
    }
  }, children);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/Input/Input.jsx
try { (() => {
function Input(props) {
  const {
    value,
    onChange,
    placeholder = '',
    prefix = '$',
    onKeyDown
  } = props;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--space-3)',
      background: 'rgba(0,0,0,0.4)',
      border: '1px solid var(--grey-line)',
      padding: '8px 12px',
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)',
      fontSize: 'var(--text-sm)'
    }
  }, prefix), /*#__PURE__*/React.createElement("input", {
    value: value,
    onChange: e => onChange && onChange(e.target.value),
    onKeyDown: onKeyDown,
    placeholder: placeholder,
    style: {
      flex: 1,
      background: 'transparent',
      border: 'none',
      outline: 'none',
      color: 'var(--accent)',
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-sm)',
      letterSpacing: 'var(--tracking-normal)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      width: '7px',
      height: '14px',
      background: 'var(--accent)',
      animation: 'symbiote-blink 1s step-end infinite'
    }
  }));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Input/Input.jsx", error: String((e && e.message) || e) }); }

// components/core/Panel/Panel.jsx
try { (() => {
function Brackets({
  color
}) {
  const t = 'var(--bracket-thickness)';
  const base = {
    position: 'absolute',
    width: 'var(--bracket-size)',
    height: 'var(--bracket-size)',
    pointerEvents: 'none'
  };
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      top: -1,
      left: -1,
      borderTop: `${t} solid ${color}`,
      borderLeft: `${t} solid ${color}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      top: -1,
      right: -1,
      borderTop: `${t} solid ${color}`,
      borderRight: `${t} solid ${color}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      bottom: -1,
      left: -1,
      borderBottom: `${t} solid ${color}`,
      borderLeft: `${t} solid ${color}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      bottom: -1,
      right: -1,
      borderBottom: `${t} solid ${color}`,
      borderRight: `${t} solid ${color}`
    }
  }));
}
function Panel(props) {
  const {
    children,
    title,
    code,
    active = false,
    style
  } = props;
  const color = active ? 'var(--accent)' : 'var(--border-panel-dim)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      background: 'var(--surface-panel)',
      backdropFilter: 'var(--blur-glass)',
      WebkitBackdropFilter: 'var(--blur-glass)',
      border: `1px solid ${active ? 'var(--border-panel)' : 'var(--grey-line)'}`,
      padding: 'var(--space-5)',
      boxShadow: active ? 'var(--glow-xs)' : 'none',
      ...style
    }
  }, /*#__PURE__*/React.createElement(Brackets, {
    color: color
  }), (title || code) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginBottom: 'var(--space-4)'
    }
  }, title && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--text-xs)',
      letterSpacing: 'var(--tracking-wider)',
      textTransform: 'uppercase',
      color: 'var(--accent)'
    }
  }, title), code && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-2xs)',
      color: 'var(--text-muted)'
    }
  }, code)), children);
}
Object.assign(__ds_scope, { Panel });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Panel/Panel.jsx", error: String((e && e.message) || e) }); }

// components/core/ProgressBar/ProgressBar.jsx
try { (() => {
function ProgressBar(props) {
  const {
    value = 0,
    segments = 20,
    label,
    critical = false
  } = props;
  const filled = Math.round(value / 100 * segments);
  const color = critical ? 'var(--state-critical)' : 'var(--accent)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)'
    }
  }, label && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginBottom: '4px',
      fontSize: 'var(--text-2xs)',
      letterSpacing: 'var(--tracking-wide)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", null, label), /*#__PURE__*/React.createElement("span", {
    style: {
      color
    }
  }, value, "%")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: '2px'
    }
  }, Array.from({
    length: segments
  }).map((_, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      width: '5px',
      height: '10px',
      background: i < filled ? color : 'var(--grey-line)',
      boxShadow: i < filled ? `0 0 4px ${color}` : 'none'
    }
  }))));
}
Object.assign(__ds_scope, { ProgressBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/ProgressBar/ProgressBar.jsx", error: String((e && e.message) || e) }); }

// components/core/RadialGauge/RadialGauge.jsx
try { (() => {
function RadialGauge(props) {
  const {
    value = 0,
    label,
    size = 140,
    critical = false
  } = props;
  const color = critical ? 'var(--state-critical)' : 'var(--accent)';
  const r1 = size / 2 - 8,
    r2 = size / 2 - 20;
  const c1 = 2 * Math.PI * r1,
    c2 = 2 * Math.PI * r2;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      textAlign: 'center',
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: `0 0 ${size} ${size}`
  }, /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r1,
    fill: "none",
    stroke: "var(--grey-line)",
    strokeWidth: "2"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r1,
    fill: "none",
    stroke: color,
    strokeWidth: "2",
    strokeDasharray: `${value / 100 * c1} ${c1}`,
    strokeLinecap: "butt",
    transform: `rotate(-90 ${size / 2} ${size / 2})`,
    style: {
      filter: `drop-shadow(0 0 4px ${color})`
    }
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r2,
    fill: "none",
    stroke: "var(--grey-line)",
    strokeWidth: "1",
    strokeDasharray: "3 4"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r2,
    fill: "none",
    stroke: color,
    strokeWidth: "1",
    strokeDasharray: `${Math.min(value + 15, 100) / 100 * c2} ${c2}`,
    transform: `rotate(-90 ${size / 2} ${size / 2})`,
    opacity: "0.5"
  }), /*#__PURE__*/React.createElement("text", {
    x: "50%",
    y: "47%",
    textAnchor: "middle",
    fill: color,
    fontSize: size * 0.16,
    fontFamily: "var(--font-mono)",
    fontWeight: "700"
  }, value), /*#__PURE__*/React.createElement("text", {
    x: "50%",
    y: "60%",
    textAnchor: "middle",
    fill: "var(--text-muted)",
    fontSize: size * 0.06,
    fontFamily: "var(--font-mono)",
    letterSpacing: "2"
  }, "%")), label && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-2xs)',
      letterSpacing: 'var(--tracking-wider)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginTop: '-6px'
    }
  }, label));
}
Object.assign(__ds_scope, { RadialGauge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/RadialGauge/RadialGauge.jsx", error: String((e && e.message) || e) }); }

// components/core/Switch/Switch.jsx
try { (() => {
function Switch(props) {
  const {
    checked = false,
    onChange,
    label
  } = props;
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 'var(--space-3)',
      cursor: 'pointer',
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    onClick: () => onChange && onChange(!checked),
    style: {
      width: '34px',
      height: '16px',
      border: `1px solid ${checked ? 'var(--accent)' : 'var(--grey-line)'}`,
      position: 'relative',
      boxShadow: checked ? 'var(--glow-xs)' : 'none',
      transition: 'all var(--dur-fast) var(--ease-symbiote)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: '2px',
      left: checked ? '19px' : '2px',
      width: '11px',
      height: '11px',
      background: checked ? 'var(--accent)' : 'var(--text-muted)',
      transition: 'left var(--dur-fast) var(--ease-symbiote)'
    }
  })), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-xs)',
      letterSpacing: 'var(--tracking-wide)',
      textTransform: 'uppercase',
      color: checked ? 'var(--accent)' : 'var(--text-muted)'
    }
  }, label));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Switch/Switch.jsx", error: String((e && e.message) || e) }); }

// components/core/Tabs/Tabs.jsx
try { (() => {
function Tabs(props) {
  const {
    items,
    active,
    onChange
  } = props;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 'var(--space-7)',
      fontFamily: 'var(--font-mono)'
    }
  }, items.map(it => {
    const isActive = it === active;
    return /*#__PURE__*/React.createElement("div", {
      key: it,
      onClick: () => onChange && onChange(it),
      style: {
        cursor: 'pointer',
        paddingBottom: 'var(--space-2)',
        fontSize: 'var(--text-sm)',
        letterSpacing: 'var(--tracking-wider)',
        textTransform: 'uppercase',
        color: isActive ? 'var(--accent)' : 'var(--text-muted)',
        borderBottom: `1px solid ${isActive ? 'var(--accent)' : 'transparent'}`,
        textShadow: isActive ? '0 0 8px var(--state-ok-glow)' : 'none',
        transition: 'all var(--dur-fast) var(--ease-symbiote)'
      }
    }, it);
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tabs/Tabs.jsx", error: String((e && e.message) || e) }); }

// components/core/Tooltip/Tooltip.jsx
try { (() => {
function Tooltip(props) {
  const {
    children,
    label
  } = props;
  const [show, setShow] = React.useState(false);
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'inline-block'
    },
    onMouseEnter: () => setShow(true),
    onMouseLeave: () => setShow(false)
  }, children, show && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      bottom: 'calc(100% + 6px)',
      left: '50%',
      transform: 'translateX(-50%)',
      background: 'var(--surface-panel-strong)',
      backdropFilter: 'var(--blur-glass)',
      border: '1px solid var(--border-panel)',
      color: 'var(--accent)',
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-2xs)',
      letterSpacing: 'var(--tracking-wide)',
      textTransform: 'uppercase',
      padding: '4px 8px',
      whiteSpace: 'nowrap',
      boxShadow: 'var(--glow-xs)',
      zIndex: 10
    }
  }, label));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tooltip/Tooltip.jsx", error: String((e && e.message) || e) }); }

// ui_kits/dashboard/ActivityFeed.jsx
try { (() => {
function ActivityFeed() {
  const {
    Icon
  } = window.SymbioteOSDesignSystem_5d2af6;
  const sevIcon = {
    ok: 'check-circle-2',
    warning: 'alert-triangle',
    critical: 'shield-alert'
  };
  const sevColor = {
    ok: 'var(--accent)',
    warning: 'var(--blue-bright)',
    critical: 'var(--state-critical)'
  };
  const rows = [{
    t: '04:12:08',
    sev: 'ok',
    msg: 'PORT SCAN COMPLETE — 24 hosts, 3 open'
  }, {
    t: '04:11:52',
    sev: 'ok',
    msg: 'HANDSHAKE VERIFIED node/14A2'
  }, {
    t: '04:11:30',
    sev: 'warning',
    msg: 'RETRY: packet loss 2.4% on eth1'
  }, {
    t: '04:10:57',
    sev: 'critical',
    msg: 'INTRUSION ATTEMPT BLOCKED 10.0.4.91'
  }, {
    t: '04:10:41',
    sev: 'ok',
    msg: 'SIGNATURE DB UPDATED v88.213'
  }, {
    t: '04:10:02',
    sev: 'ok',
    msg: 'INTEGRATION PULSE STABLE'
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '8px'
    }
  }, rows.map((r, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-2xs)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-muted)'
    }
  }, r.t), /*#__PURE__*/React.createElement("span", {
    style: {
      color: sevColor[r.sev],
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: sevIcon[r.sev],
    size: 11,
    strokeWidth: 2
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      color: r.sev === 'critical' ? 'var(--state-critical)' : 'var(--text-body)'
    }
  }, r.msg))));
}
window.ActivityFeed = ActivityFeed;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/dashboard/ActivityFeed.jsx", error: String((e && e.message) || e) }); }

// ui_kits/dashboard/Dashboard.jsx
try { (() => {
function Dashboard(props) {
  const {
    onExit
  } = props || {};
  const {
    Panel,
    Badge,
    Button,
    Tabs,
    Input,
    RadialGauge,
    IconButton,
    Icon
  } = window.SymbioteOSDesignSystem_5d2af6;
  const {
    Hologram,
    MicroReadout,
    Waveform,
    ScanThumbs,
    ActivityFeed
  } = window;
  const [tab, setTab] = React.useState('SECURITY');
  const [clock, setClock] = React.useState(new Date());
  const [cmd, setCmd] = React.useState('');
  const [log, setLog] = React.useState(['scan initiated on 10.0.0.0/24', '24 hosts discovered, 3 vulnerable']);
  React.useEffect(() => {
    const id = setInterval(() => setClock(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  const runAction = name => setLog(l => [...l, `${name.toLowerCase()} executed — awaiting response...`].slice(-4));
  const submitCmd = e => {
    if (e.key === 'Enter' && cmd.trim()) {
      setLog(l => [...l, cmd].slice(-4));
      setCmd('');
    }
  };
  const time = clock.toLocaleTimeString('en-US', {
    hour12: false
  });
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: '1920px',
      height: '1080px',
      background: 'var(--bg-void)',
      position: 'relative',
      overflow: 'hidden',
      fontFamily: 'var(--font-mono)',
      color: 'var(--text-body)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: 'linear-gradient(var(--grid-line) 1px, transparent 1px), linear-gradient(90deg, var(--grid-line) 1px, transparent 1px)',
      backgroundSize: '28px 28px',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      height: '140px',
      background: 'linear-gradient(to bottom, transparent, rgba(0,217,255,.05), transparent)',
      animation: 'symbiote-scan 6s linear infinite',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: '56px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 28px',
      borderBottom: '1px solid var(--grey-line)',
      background: 'rgba(0,10,6,0.4)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '14px'
    }
  }, onExit && /*#__PURE__*/React.createElement(IconButton, {
    label: "back to desktop",
    onClick: onExit
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "arrow-left",
    size: 14
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      width: '14px',
      height: '14px',
      background: 'var(--accent)',
      transform: 'rotate(45deg)',
      boxShadow: 'var(--glow-md)',
      animation: 'symbiote-glow-pulse var(--dur-pulse) ease-in-out infinite'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)',
      fontSize: 'var(--text-lg)',
      letterSpacing: 'var(--tracking-widest)',
      fontFamily: 'var(--font-display)',
      fontWeight: 'var(--weight-bold)'
    }
  }, "SYMBIOTE OS")), /*#__PURE__*/React.createElement(Tabs, {
    items: ['SECURITY', 'TOOLS', 'NETWORK', 'PROFILE'],
    active: tab,
    onChange: setTab
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '20px',
      fontSize: 'var(--text-xs)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-muted)'
    }
  }, "UPTIME 14:02:37"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, time), /*#__PURE__*/React.createElement(Badge, {
    severity: "ok",
    pulse: true
  }, "LINK ACTIVE"), /*#__PURE__*/React.createElement(IconButton, {
    label: "alerts"
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "bell",
    size: 14
  })), /*#__PURE__*/React.createElement(IconButton, {
    label: "profile"
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "user",
    size: 14
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'grid',
      gridTemplateColumns: '300px 1fr 300px',
      gap: '18px',
      padding: '18px 20px',
      height: 'calc(1080px - 56px - 150px)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '16px'
    }
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "SYSTEM DIAGNOSTICS",
    code: "SYM_EM_03.4",
    active: true,
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement(MicroReadout, {
    code: "X_300:1",
    label: "CPU THREAD LOAD",
    value: "64%",
    active: 5
  }), /*#__PURE__*/React.createElement(MicroReadout, {
    code: "INTEGRATION_0001",
    label: "MEMORY ALLOC",
    value: "41%",
    active: 3
  }), /*#__PURE__*/React.createElement(MicroReadout, {
    code: "CROSS_SE",
    label: "ENTROPY POOL",
    value: "88%",
    active: 7
  }), /*#__PURE__*/React.createElement(MicroReadout, {
    code: "NODE::14A2",
    label: "KERNEL SYNC",
    value: "OK",
    active: 8
  })), /*#__PURE__*/React.createElement(Panel, {
    title: "OSCILLOSCOPE",
    code: "CH.02"
  }, /*#__PURE__*/React.createElement(Waveform, {
    seed: 3
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: '10px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: '60px',
      marginTop: '4px'
    }
  }, /*#__PURE__*/React.createElement(RadialGauge, {
    value: 34,
    label: "INTEGRATION RATE",
    size: 150
  }), /*#__PURE__*/React.createElement(RadialGauge, {
    value: 87,
    label: "THREAT LEVEL",
    size: 150,
    critical: true
  })), /*#__PURE__*/React.createElement(Hologram, null), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: '14px',
      marginTop: '4px'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    icon: "radar",
    onClick: () => runAction('NETWORK SCAN')
  }, "NETWORK SCAN"), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    icon: "bug",
    onClick: () => runAction('VULN CHECK')
  }, "VULN CHECK"), /*#__PURE__*/React.createElement(Button, {
    variant: "danger",
    icon: "zap",
    onClick: () => runAction('EXPLOIT')
  }, "EXPLOIT"), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    icon: "terminal",
    onClick: () => runAction('TERMINAL')
  }, "TERMINAL"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '16px'
    }
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "SCAN GRID",
    code: "6 NODES"
  }, /*#__PURE__*/React.createElement(ScanThumbs, null)), /*#__PURE__*/React.createElement(Panel, {
    title: "ACTIVITY FEED",
    code: "LIVE",
    active: true,
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement(ActivityFeed, null)))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      height: '150px',
      padding: '10px 20px',
      borderTop: '1px solid var(--grey-line)',
      background: 'rgba(0,10,6,0.5)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-2xs)',
      color: 'var(--text-muted)',
      marginBottom: '6px',
      display: 'flex',
      flexDirection: 'column',
      gap: '2px'
    }
  }, log.map((l, i) => /*#__PURE__*/React.createElement("span", {
    key: i
  }, "> ", l))), /*#__PURE__*/React.createElement(Input, {
    prefix: "symbiote >",
    value: cmd,
    onChange: setCmd,
    placeholder: "enter command",
    onKeyDown: submitCmd
  })));
}
window.Dashboard = Dashboard;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/dashboard/Dashboard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/dashboard/Hologram.jsx
try { (() => {
function Hologram() {
  const rings = [0, 1, 2, 3, 4, 5];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: '360px',
      height: '360px',
      perspective: '900px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: '50%',
      background: 'radial-gradient(circle, rgba(0,217,255,0.10) 0%, rgba(0,217,255,0.02) 55%, transparent 75%)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: '20%',
      transformStyle: 'preserve-3d',
      animation: 'symbiote-spin 18s linear infinite'
    }
  }, rings.map(i => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: '50%',
      border: '1px solid rgba(0,217,255,0.5)',
      transform: `rotateX(${70 - i * 6}deg) rotateZ(${i * 30}deg) scale(${1 - i * 0.08})`,
      boxShadow: '0 0 14px rgba(0,217,255,0.25)'
    }
  })), Array.from({
    length: 14
  }).map((_, i) => {
    const a = i / 14 * Math.PI * 2;
    const rad = 46 + i % 3 * 8;
    const x = 50 + Math.cos(a) * rad,
      y = 50 + Math.sin(a) * rad * 0.5;
    return /*#__PURE__*/React.createElement("div", {
      key: 'n' + i,
      style: {
        position: 'absolute',
        left: `${x}%`,
        top: `${y}%`,
        width: '3px',
        height: '3px',
        background: 'var(--accent)',
        borderRadius: '50%',
        boxShadow: '0 0 6px var(--accent)',
        transform: `translateZ(${i % 5 * 10}px)`
      }
    });
  })), /*#__PURE__*/React.createElement("svg", {
    style: {
      position: 'absolute',
      inset: 0
    },
    viewBox: "0 0 200 200"
  }, /*#__PURE__*/React.createElement("ellipse", {
    cx: "100",
    cy: "100",
    rx: "78",
    ry: "30",
    fill: "none",
    stroke: "rgba(0,217,255,.35)",
    strokeWidth: "0.6"
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "100",
    cy: "100",
    rx: "60",
    ry: "46",
    fill: "none",
    stroke: "rgba(0,217,255,.25)",
    strokeWidth: "0.6",
    transform: "rotate(35 100 100)"
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "100",
    cy: "100",
    rx: "68",
    ry: "20",
    fill: "none",
    stroke: "rgba(0,217,255,.3)",
    strokeWidth: "0.6",
    transform: "rotate(110 100 100)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: '-6px',
      left: '50%',
      transform: 'translateX(-50%)',
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--text-2xs)',
      letterSpacing: 'var(--tracking-wider)',
      color: 'var(--text-muted)',
      textTransform: 'uppercase',
      whiteSpace: 'nowrap'
    }
  }, "SYMBIONT MASS // LIVE RENDER"));
}
window.Hologram = Hologram;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/dashboard/Hologram.jsx", error: String((e && e.message) || e) }); }

// ui_kits/dashboard/MicroReadout.jsx
try { (() => {
function MicroReadout({
  code,
  label,
  value,
  bars = 8,
  active = 4
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      marginBottom: '10px',
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      fontSize: 'var(--text-2xs)',
      color: 'var(--text-muted)',
      letterSpacing: '0.05em'
    }
  }, /*#__PURE__*/React.createElement("span", null, code), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, value)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-2xs)',
      color: 'var(--text-body)',
      marginBottom: '3px'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: '2px'
    }
  }, Array.from({
    length: bars
  }).map((_, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      flex: 1,
      height: '4px',
      background: i < active ? 'var(--accent)' : 'var(--grey-line)',
      boxShadow: i < active ? '0 0 3px var(--accent)' : 'none'
    }
  }))));
}
window.MicroReadout = MicroReadout;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/dashboard/MicroReadout.jsx", error: String((e && e.message) || e) }); }

// ui_kits/dashboard/ScanThumbs.jsx
try { (() => {
function ScanThumbs() {
  const items = ['NODE_14A', 'NODE_09C', 'NODE_22F', 'NODE_31B', 'NODE_07E', 'NODE_18D'];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gap: '6px'
    }
  }, items.map((it, i) => /*#__PURE__*/React.createElement("div", {
    key: it,
    style: {
      position: 'relative',
      aspectRatio: '1',
      background: 'rgba(0,217,255,0.04)',
      border: '1px solid var(--grey-line)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: `repeating-linear-gradient(${i * 35}deg, rgba(0,217,255,.12) 0px, rgba(0,217,255,.12) 1px, transparent 1px, transparent 6px)`
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: '2px',
      left: '3px',
      fontFamily: 'var(--font-mono)',
      fontSize: '6px',
      color: 'var(--accent)'
    }
  }, it))));
}
window.ScanThumbs = ScanThumbs;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/dashboard/ScanThumbs.jsx", error: String((e && e.message) || e) }); }

// ui_kits/dashboard/Waveform.jsx
try { (() => {
function Waveform({
  seed = 1,
  color = 'var(--accent)'
}) {
  const pts = React.useMemo(() => {
    let s = seed;
    const rand = () => {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280;
    };
    return Array.from({
      length: 48
    }).map((_, i) => 8 + rand() * 24 + Math.sin(i / 3 + seed) * 8);
  }, [seed]);
  const d = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${i * 4} ${40 - p}`).join(' ');
  return /*#__PURE__*/React.createElement("svg", {
    width: "100%",
    height: "44",
    viewBox: "0 0 192 44",
    preserveAspectRatio: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: d,
    fill: "none",
    stroke: color,
    strokeWidth: "1",
    style: {
      filter: `drop-shadow(0 0 3px ${color})`
    }
  }));
}
window.Waveform = Waveform;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/dashboard/Waveform.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/Desktop.jsx
try { (() => {
const APPS = [{
  id: 'terminal',
  title: 'TERMINAL',
  icon: 'terminal',
  w: 480,
  h: 320,
  x: 90,
  y: 90
}, {
  id: 'files',
  title: 'FILE MANAGER',
  icon: 'folder',
  w: 520,
  h: 340,
  x: 620,
  y: 120
}, {
  id: 'tools',
  title: 'SECURITY TOOLS',
  icon: 'shield',
  w: 640,
  h: 300,
  x: 220,
  y: 260
}, {
  id: 'network',
  title: 'NETWORK MONITOR',
  icon: 'wifi',
  w: 520,
  h: 300,
  x: 900,
  y: 400
}];
function Desktop(props) {
  const {
    onCommandCenter
  } = props;
  const {
    WindowFrame,
    Dock,
    TopBar,
    TerminalApp,
    FileManagerApp,
    ToolsApp,
    NetworkApp
  } = window;
  const [wins, setWins] = React.useState({
    tools: {
      open: true,
      z: 1
    }
  });
  const zRef = React.useRef(1);
  const launch = id => {
    setWins(w => {
      if (w[id] && w[id].open) {
        zRef.current += 1;
        return {
          ...w,
          [id]: {
            ...w[id],
            z: zRef.current
          }
        };
      }
      zRef.current += 1;
      return {
        ...w,
        [id]: {
          open: true,
          z: zRef.current
        }
      };
    });
  };
  const close = id => setWins(w => ({
    ...w,
    [id]: {
      ...w[id],
      open: false
    }
  }));
  const focus = id => {
    zRef.current += 1;
    setWins(w => ({
      ...w,
      [id]: {
        ...w[id],
        z: zRef.current
      }
    }));
  };
  const content = {
    terminal: /*#__PURE__*/React.createElement(TerminalApp, null),
    files: /*#__PURE__*/React.createElement(FileManagerApp, null),
    tools: /*#__PURE__*/React.createElement(ToolsApp, null),
    network: /*#__PURE__*/React.createElement(NetworkApp, null)
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: '1920px',
      height: '1080px',
      background: 'var(--bg-void)',
      position: 'relative',
      overflow: 'hidden',
      color: 'var(--text-body)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: 'linear-gradient(var(--grid-line) 1px, transparent 1px), linear-gradient(90deg, var(--grid-line) 1px, transparent 1px)',
      backgroundSize: '40px 40px',
      pointerEvents: 'none',
      opacity: 0.6
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      height: '140px',
      background: 'linear-gradient(to bottom, transparent, rgba(0,217,255,.03), transparent)',
      animation: 'symbiote-scan 9s linear infinite',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement(TopBar, {
    onCommandCenter: onCommandCenter
  }), APPS.filter(a => wins[a.id] && wins[a.id].open).map(a => /*#__PURE__*/React.createElement(WindowFrame, {
    key: a.id,
    title: a.title,
    icon: a.icon,
    x: a.x,
    y: a.y,
    w: a.w,
    h: a.h,
    z: wins[a.id].z,
    focused: wins[a.id].z === Math.max(...Object.values(wins).map(w => w.z || 0)),
    onFocus: () => focus(a.id),
    onClose: () => close(a.id),
    onMinimize: () => close(a.id)
  }, content[a.id])), /*#__PURE__*/React.createElement(Dock, {
    apps: APPS,
    openIds: Object.keys(wins).filter(id => wins[id].open),
    onLaunch: launch
  }));
}
window.Desktop = Desktop;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/Desktop.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/Dock.jsx
try { (() => {
function Dock(props) {
  const {
    apps,
    openIds,
    onLaunch
  } = props;
  const {
    Icon
  } = window.SymbioteOSDesignSystem_5d2af6;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: '26px',
      left: '50%',
      transform: 'translateX(-50%)',
      display: 'flex',
      gap: '10px',
      padding: '12px 18px',
      background: 'var(--surface-panel-strong)',
      backdropFilter: 'var(--blur-glass)',
      WebkitBackdropFilter: 'var(--blur-glass)',
      border: '1px solid var(--border-panel-dim)'
    }
  }, apps.map(a => {
    const open = openIds.includes(a.id);
    return /*#__PURE__*/React.createElement("div", {
      key: a.id,
      title: a.title,
      onClick: () => onLaunch(a.id),
      style: {
        width: '48px',
        height: '48px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '6px',
        cursor: 'pointer',
        color: open ? 'var(--accent)' : 'var(--text-muted)'
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: a.icon,
      size: 21,
      strokeWidth: 1.5
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        width: '4px',
        height: '2px',
        background: open ? 'var(--accent)' : 'transparent',
        boxShadow: open ? '0 0 4px var(--accent)' : 'none'
      }
    }));
  }));
}
window.Dock = Dock;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/Dock.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/FileManagerApp.jsx
try { (() => {
function FileManagerApp() {
  const {
    Icon
  } = window.SymbioteOSDesignSystem_5d2af6;
  const folders = ['home', 'tools', 'loot', 'scripts'];
  const [active, setActive] = React.useState('tools');
  const files = {
    home: [['notes.md', '2.1K'], ['.bash_history', '890B']],
    tools: [['nmap', 'bin'], ['metasploit-framework', 'bin'], ['wireshark', 'bin']],
    loot: [['hashes.txt', '14K'], ['scan_10.0.0.0-24.xml', '38K']],
    scripts: [['recon.sh', '1.2K'], ['exfil.py', '3.4K']]
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '130px 1fr',
      gap: '20px',
      height: '100%',
      fontSize: 'var(--text-sm)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '10px',
      borderRight: '1px solid var(--grey-line)',
      paddingRight: '14px'
    }
  }, folders.map(f => /*#__PURE__*/React.createElement("div", {
    key: f,
    onClick: () => setActive(f),
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      cursor: 'pointer',
      padding: '6px 8px',
      color: active === f ? 'var(--accent)' : 'var(--text-muted)',
      background: active === f ? 'rgba(0,217,255,0.06)' : 'transparent',
      textTransform: 'uppercase',
      letterSpacing: 'var(--tracking-wide)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "folder",
    size: 13
  }), "/", f))), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 70px',
      color: 'var(--text-muted)',
      marginBottom: '10px',
      letterSpacing: 'var(--tracking-wide)',
      fontSize: 'var(--text-xs)'
    }
  }, /*#__PURE__*/React.createElement("span", null, "NAME"), /*#__PURE__*/React.createElement("span", null, "SIZE")), (files[active] || []).map(([name, size]) => /*#__PURE__*/React.createElement("div", {
    key: name,
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 70px',
      padding: '8px 0',
      borderBottom: '1px solid var(--grey-line)',
      color: 'var(--text-body)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "file-text",
    size: 12
  }), name), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-muted)'
    }
  }, size)))));
}
window.FileManagerApp = FileManagerApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/FileManagerApp.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/NetworkApp.jsx
try { (() => {
function NetworkApp() {
  const {
    Badge
  } = window.SymbioteOSDesignSystem_5d2af6;
  const hosts = [{
    ip: '10.0.0.1',
    host: 'gateway.local',
    status: 'ok',
    ports: '22, 80, 443'
  }, {
    ip: '10.0.0.14',
    host: 'node-14a2',
    status: 'ok',
    ports: '22'
  }, {
    ip: '10.0.0.91',
    host: 'unknown',
    status: 'critical',
    ports: '4444'
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-sm)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '110px 1fr 100px 110px',
      color: 'var(--text-muted)',
      marginBottom: '12px',
      letterSpacing: 'var(--tracking-wide)',
      fontSize: 'var(--text-xs)'
    }
  }, /*#__PURE__*/React.createElement("span", null, "IP"), /*#__PURE__*/React.createElement("span", null, "HOST"), /*#__PURE__*/React.createElement("span", null, "STATUS"), /*#__PURE__*/React.createElement("span", null, "PORTS")), hosts.map(h => /*#__PURE__*/React.createElement("div", {
    key: h.ip,
    style: {
      display: 'grid',
      gridTemplateColumns: '110px 1fr 100px 110px',
      padding: '10px 0',
      borderBottom: '1px solid var(--grey-line)',
      alignItems: 'center',
      color: 'var(--text-body)'
    }
  }, /*#__PURE__*/React.createElement("span", null, h.ip), /*#__PURE__*/React.createElement("span", null, h.host), /*#__PURE__*/React.createElement(Badge, {
    severity: h.status,
    pulse: h.status !== 'ok'
  }, h.status === 'ok' ? 'UP' : 'ALERT'), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-muted)',
      fontSize: 'var(--text-xs)'
    }
  }, h.ports))));
}
window.NetworkApp = NetworkApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/NetworkApp.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/OS.jsx
try { (() => {
function OS() {
  const {
    Dashboard
  } = window;
  const [view, setView] = React.useState('desktop');
  if (view === 'command') return /*#__PURE__*/React.createElement(window.Dashboard, {
    onExit: () => setView('desktop')
  });
  return /*#__PURE__*/React.createElement(window.Desktop, {
    onCommandCenter: () => setView('command')
  });
}
window.OS = OS;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/OS.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/TerminalApp.jsx
try { (() => {
function TerminalApp() {
  const {
    Input
  } = window.SymbioteOSDesignSystem_5d2af6;
  const [lines, setLines] = React.useState(['symbiote os v2.4 — kernel 6.9.1-symbiote', 'type "help" for available commands']);
  const [cmd, setCmd] = React.useState('');
  const responses = {
    help: 'commands: nmap, whoami, ls, uname, clear',
    whoami: 'operator@symbiote',
    ls: 'tools/  loot/  scripts/  notes.md',
    uname: 'SymbioteOS 2.4.0 x86_64 GNU/Linux',
    nmap: 'starting nmap 7.94 — scanning 10.0.0.0/24...\n24 hosts up, 3 with open ports'
  };
  const run = e => {
    if (e.key !== 'Enter' || !cmd.trim()) return;
    const key = cmd.trim().split(' ')[0].toLowerCase();
    if (key === 'clear') {
      setLines([]);
      setCmd('');
      return;
    }
    const out = responses[key] || `command not found: ${key}`;
    setLines(l => [...l, `$ ${cmd}`, out]);
    setCmd('');
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      fontSize: 'var(--text-sm)',
      color: 'var(--accent)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto',
      whiteSpace: 'pre-wrap',
      marginBottom: '10px',
      color: 'var(--text-body)'
    }
  }, lines.map((l, i) => /*#__PURE__*/React.createElement("div", {
    key: i
  }, l))), /*#__PURE__*/React.createElement(Input, {
    prefix: "symbiote >",
    value: cmd,
    onChange: setCmd,
    onKeyDown: run,
    placeholder: "enter command"
  }));
}
window.TerminalApp = TerminalApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/TerminalApp.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/ToolsApp.jsx
try { (() => {
function ToolsApp() {
  const {
    Icon
  } = window.SymbioteOSDesignSystem_5d2af6;
  const [status, setStatus] = React.useState('');
  const tools = [{
    name: 'Nmap',
    desc: 'Network discovery & port scanning',
    icon: 'radar'
  }, {
    name: 'Wireshark',
    desc: 'Packet capture & analysis',
    icon: 'activity'
  }, {
    name: 'Metasploit',
    desc: 'Exploitation framework',
    icon: 'zap'
  }, {
    name: 'Aircrack-ng',
    desc: 'Wireless network auditing',
    icon: 'wifi'
  }, {
    name: 'Burp Suite',
    desc: 'Web app security testing',
    icon: 'bug'
  }, {
    name: 'SQLmap',
    desc: 'SQL injection testing',
    icon: 'database'
  }];
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gap: '16px'
    }
  }, tools.map(t => /*#__PURE__*/React.createElement("div", {
    key: t.name,
    onClick: () => setStatus(`launching ${t.name.toLowerCase()}...`),
    style: {
      border: '1px solid var(--grey-line)',
      padding: '20px 16px',
      cursor: 'pointer',
      textAlign: 'center',
      transition: 'all var(--dur-fast) var(--ease-symbiote)'
    },
    onMouseEnter: e => {
      e.currentTarget.style.borderColor = 'var(--accent)';
      e.currentTarget.style.boxShadow = 'var(--glow-xs)';
    },
    onMouseLeave: e => {
      e.currentTarget.style.borderColor = 'var(--grey-line)';
      e.currentTarget.style.boxShadow = 'none';
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--accent)',
      marginBottom: '10px',
      display: 'flex',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: t.icon,
    size: 24
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--text-sm)',
      color: 'var(--text-body)',
      letterSpacing: 'var(--tracking-wide)',
      marginBottom: '5px'
    }
  }, t.name), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-xs)',
      color: 'var(--text-muted)'
    }
  }, t.desc)))), status && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: '16px',
      fontSize: 'var(--text-sm)',
      color: 'var(--accent)'
    }
  }, "> ", status));
}
window.ToolsApp = ToolsApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/ToolsApp.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/TopBar.jsx
try { (() => {
function TopBar(props) {
  const {
    onCommandCenter
  } = props;
  const {
    Badge,
    IconButton,
    Icon
  } = window.SymbioteOSDesignSystem_5d2af6;
  const [clock, setClock] = React.useState(new Date());
  React.useEffect(() => {
    const id = setInterval(() => setClock(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  const time = clock.toLocaleTimeString('en-US', {
    hour12: false
  });
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: '56px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 28px',
      borderBottom: '1px solid var(--grey-line)',
      background: 'rgba(0,10,16,0.4)',
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '14px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '14px',
      height: '14px',
      background: 'var(--accent)',
      transform: 'rotate(45deg)',
      boxShadow: 'var(--glow-md)',
      animation: 'symbiote-glow-pulse var(--dur-pulse) ease-in-out infinite'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)',
      fontSize: 'var(--text-lg)',
      letterSpacing: 'var(--tracking-widest)',
      fontFamily: 'var(--font-display)',
      fontWeight: 'var(--weight-bold)'
    }
  }, "SYMBIOTE OS")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '22px',
      fontSize: 'var(--text-xs)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: onCommandCenter,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      cursor: 'pointer',
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "activity",
    size: 14
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      letterSpacing: 'var(--tracking-wide)'
    }
  }, "COMMAND CENTER")), /*#__PURE__*/React.createElement(Badge, {
    severity: "ok",
    pulse: true
  }, "LINK ACTIVE"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, time), /*#__PURE__*/React.createElement(IconButton, {
    label: "settings"
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "settings",
    size: 14
  }))));
}
window.TopBar = TopBar;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/TopBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/WindowFrame.jsx
try { (() => {
function WindowFrame(props) {
  const {
    title,
    icon,
    x,
    y,
    w,
    h,
    z,
    focused,
    onFocus,
    onClose,
    onMinimize,
    children
  } = props;
  const {
    Icon,
    IconButton
  } = window.SymbioteOSDesignSystem_5d2af6;
  const [pos, setPos] = React.useState({
    x,
    y
  });
  const onMouseDown = e => {
    onFocus();
    const startX = e.clientX,
      startY = e.clientY,
      origX = pos.x,
      origY = pos.y;
    const move = ev => setPos({
      x: origX + ev.clientX - startX,
      y: origY + ev.clientY - startY
    });
    const up = () => {
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
    };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  };
  const bc = focused ? 'var(--accent)' : 'var(--grey-line)';
  const bt = 'var(--bracket-thickness)';
  const bb = {
    position: 'absolute',
    width: '16px',
    height: '16px',
    pointerEvents: 'none'
  };
  return /*#__PURE__*/React.createElement("div", {
    onMouseDown: onFocus,
    style: {
      position: 'absolute',
      left: pos.x,
      top: pos.y,
      width: w,
      height: h,
      zIndex: z,
      background: 'var(--surface-panel-strong)',
      backdropFilter: 'var(--blur-glass)',
      WebkitBackdropFilter: 'var(--blur-glass)',
      border: `1px solid ${focused ? 'var(--border-panel)' : 'var(--grey-line)'}`,
      boxShadow: focused ? 'var(--glow-sm)' : 'none',
      display: 'flex',
      flexDirection: 'column',
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...bb,
      top: -1,
      left: -1,
      borderTop: `${bt} solid ${bc}`,
      borderLeft: `${bt} solid ${bc}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...bb,
      top: -1,
      right: -1,
      borderTop: `${bt} solid ${bc}`,
      borderRight: `${bt} solid ${bc}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...bb,
      bottom: -1,
      left: -1,
      borderBottom: `${bt} solid ${bc}`,
      borderLeft: `${bt} solid ${bc}`
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...bb,
      bottom: -1,
      right: -1,
      borderBottom: `${bt} solid ${bc}`,
      borderRight: `${bt} solid ${bc}`
    }
  }), /*#__PURE__*/React.createElement("div", {
    onMouseDown: onMouseDown,
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '12px 16px',
      borderBottom: '1px solid var(--grey-line)',
      cursor: 'move',
      userSelect: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '10px',
      color: focused ? 'var(--accent)' : 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: icon,
    size: 14,
    strokeWidth: 1.75
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--text-sm)',
      letterSpacing: 'var(--tracking-wider)',
      textTransform: 'uppercase'
    }
  }, title)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: '6px'
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    label: "minimize",
    onClick: onMinimize
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "minus",
    size: 11
  })), /*#__PURE__*/React.createElement(IconButton, {
    label: "close",
    onClick: onClose
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "x",
    size: 11
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto',
      padding: '20px'
    }
  }, children));
}
window.WindowFrame = WindowFrame;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/WindowFrame.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Panel = __ds_scope.Panel;

__ds_ns.ProgressBar = __ds_scope.ProgressBar;

__ds_ns.RadialGauge = __ds_scope.RadialGauge;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Tabs = __ds_scope.Tabs;

__ds_ns.Tooltip = __ds_scope.Tooltip;

})();
