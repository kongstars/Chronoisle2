export class SimilarityUtils {
  static calculateSimilarity(a: string, b: string): number {
    const left = a.trim().toLowerCase();
    const right = b.trim().toLowerCase();
    if (left.length === 0 || right.length === 0) {
      return 0;
    }
    if (left === right) {
      return 1;
    }
    if (left.includes(right) || right.includes(left)) {
      return Math.min(left.length, right.length) / Math.max(left.length, right.length);
    }
    let same = 0;
    const rightSet: Set<string> = new Set(right.split(''));
    for (const ch of left.split('')) {
      if (rightSet.has(ch)) {
        same++;
      }
    }
    return same / Math.max(left.length, right.length);
  }
}
