// Master card positions are one-based; persisted user positions are zero-based.
window.CompanyPortalWorkspacePolicy = {
  valid(cards, keys) {
    return Array.isArray(cards) && cards.length === keys.length
      && new Set(cards.map(card => card?.cardKey)).size === keys.length
      && cards.every(card => keys.includes(card?.cardKey) && typeof card.cardName === 'string'
        && card.cardName.trim().length > 0 && card.cardName.length <= 200
        && typeof card.isFixed === 'boolean' && Number.isInteger(card.displayOrder)
        && card.displayOrder >= 1 && (!card.isFixed || card.displayOrder <= keys.length))
      && new Set(cards.filter(card => card.isFixed).map(card => card.displayOrder)).size === cards.filter(card => card.isFixed).length;
  },
  normalize(keys, cards) {
    const result = new Array(keys.length), fixed = new Set();
    cards.filter(card => card.isFixed).forEach(card => {
      result[card.displayOrder - 1] = card.cardKey;
      fixed.add(card.cardKey);
    });
    const movable = keys.filter(key => !fixed.has(key));
    let next = 0;
    for (let index = 0; index < result.length; index++) if (!result[index]) result[index] = movable[next++];
    return result;
  }
};
