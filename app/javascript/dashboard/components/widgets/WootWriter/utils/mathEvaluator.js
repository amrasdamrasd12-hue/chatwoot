// Safe math expression evaluator — no eval/Function.
// Supported: + - * / ^ ( ) decimals, Arabic-Indic digits, percentage suffix.
//
// Percentage handling:
//   "200-20%"  → 200 - (200 * 0.20) = 160
//   "200+20%"  → 200 + (200 * 0.20) = 240
//   "200*20%"  → 200 * 0.20         = 40
//   "20%"      → 0.20
//   "5*10"     → 50

const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';
const MAX_RESULT = 1e15;

function normalizeDigits(str) {
  return str.replace(/[٠-٩]/g, d => ARABIC_INDIC.indexOf(d));
}

const TOKEN_NUMBER = 'NUM';
const TOKEN_OP = 'OP';
const TOKEN_LPAREN = 'LP';
const TOKEN_RPAREN = 'RP';

function tokenize(expr) {
  const tokens = [];
  let i = 0;
  while (i < expr.length) {
    const ch = expr[i];
    if (/\s/.test(ch)) {
      i += 1;
      // eslint-disable-next-line no-continue
      continue;
    }
    if (/[\d.]/.test(ch)) {
      let num = '';
      while (i < expr.length && /[\d.]/.test(expr[i])) {
        num += expr[i];
        i += 1;
      }
      const isPercent = expr[i] === '%';
      if (isPercent) i += 1;
      tokens.push({
        type: TOKEN_NUMBER,
        value: parseFloat(num),
        percent: isPercent,
      });
    } else if ('+-*/^'.includes(ch)) {
      tokens.push({ type: TOKEN_OP, value: ch });
      i += 1;
    } else if (ch === '(') {
      tokens.push({ type: TOKEN_LPAREN });
      i += 1;
    } else if (ch === ')') {
      tokens.push({ type: TOKEN_RPAREN });
      i += 1;
    } else {
      return null;
    }
  }
  return tokens;
}

// Recursive descent parser
// Grammar:
//   expr    = term   (('+' | '-') term)*
//   term    = power  (('*' | '/') power)*
//   power   = unary  ('^' unary)*
//   unary   = '-' unary | primary
//   primary = NUMBER | '(' expr ')'

function parse(tokens) {
  let pos = 0;

  const peek = () => tokens[pos];
  const consume = () => {
    const tok = tokens[pos];
    pos += 1;
    return tok;
  };

  // Ordered bottom-up so each function is defined before it is called.

  function parsePrimary() {
    const tok = peek();
    if (!tok) return null;
    if (tok.type === TOKEN_NUMBER) {
      consume();
      return {
        value: tok.percent ? tok.value / 100 : tok.value,
        percent: tok.percent,
      };
    }
    if (tok.type === TOKEN_LPAREN) {
      consume();
      // eslint-disable-next-line no-use-before-define
      const inner = parseExpr();
      if (inner === null) return null;
      if (!peek() || peek().type !== TOKEN_RPAREN) return null;
      consume();
      return inner;
    }
    return null;
  }

  function parseUnary() {
    if (peek() && peek().type === TOKEN_OP && peek().value === '-') {
      consume();
      const operand = parseUnary();
      if (operand === null) return null;
      return { value: -operand.value, percent: operand.percent };
    }
    return parsePrimary();
  }

  function parsePower() {
    const base = parseUnary();
    if (base === null) return null;
    if (peek() && peek().type === TOKEN_OP && peek().value === '^') {
      consume();
      const exp = parseUnary();
      if (exp === null) return null;
      return { value: base.value ** exp.value, percent: false };
    }
    return base;
  }

  function parseTerm() {
    let left = parsePower();
    if (left === null) return null;
    while (peek() && peek().type === TOKEN_OP && '*/'.includes(peek().value)) {
      const op = consume().value;
      const right = parsePower();
      if (right === null) return null;
      left = {
        value: op === '*' ? left.value * right.value : left.value / right.value,
        percent: false,
      };
    }
    return left;
  }

  function parseExpr() {
    let left = parseTerm();
    if (left === null) return null;
    while (peek() && peek().type === TOKEN_OP && '+-'.includes(peek().value)) {
      const op = consume().value;
      const right = parseTerm();
      if (right === null) return null;
      const rval = right.percent ? left.value * right.value : right.value;
      left = {
        value: op === '+' ? left.value + rval : left.value - rval,
        percent: false,
      };
    }
    return left;
  }

  const result = parseExpr();
  if (result === null || pos !== tokens.length) return null;
  return result.value;
}

function formatResult(n) {
  if (!Number.isFinite(n)) return null;
  const fixed = parseFloat(n.toFixed(10));
  return String(fixed);
}

/**
 * Evaluates a math expression string.
 * Returns the formatted result string, or null if invalid.
 *
 * @param {string} raw  e.g. "5*10", "199-20%", "1.4*1.2", "(3+4)*2^3"
 * @returns {string|null}
 */
export function evaluate(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const normalized = normalizeDigits(raw.trim());
  if (!/\d/.test(normalized)) return null;
  if (!/[+\-*/^%()]/.test(normalized) && !/^\d+(\.\d+)?$/.test(normalized))
    return null;
  const tokens = tokenize(normalized);
  if (!tokens) return null;
  const result = parse(tokens);
  if (result === null || !Number.isFinite(result)) return null;
  if (Math.abs(result) > MAX_RESULT) return null;
  return formatResult(result);
}

/**
 * Detects if text ends with a math expression followed by '='.
 * Returns { expr, result } or null.
 *
 * @param {string} text
 * @returns {{ expr: string, result: string } | null}
 */
export function detectCalcExpression(text) {
  if (!text) return null;
  const normalized = normalizeDigits(text.trimEnd());
  if (!normalized.endsWith('=')) return null;
  const withoutEq = normalized.slice(0, -1).trimEnd();
  const match = withoutEq.match(/([0-9.()+\-*/^%\s]+)$/);
  if (!match) return null;
  const expr = match[1].trim();
  if (!expr) return null;
  const result = evaluate(expr);
  if (result === null) return null;
  return { expr, result };
}
