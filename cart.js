(() => {
  const storageKey = 'kopi-kita-cart-v1';
  const cartDialog = document.querySelector('[data-cart-dialog]');
  const cartItems = document.querySelector('[data-cart-items]');
  const cartCount = document.querySelector('[data-cart-count]');
  const cartTotal = document.querySelector('[data-cart-total]');
  const cartEmpty = document.querySelector('[data-cart-empty]');
  const cartStatus = document.querySelector('[data-cart-status]');
  const checkoutLink = document.querySelector('[data-checkout]');
  const products = new Map(
    [...document.querySelectorAll('[data-product-id]')].map((card) => [
      card.dataset.productId,
      {
        id: card.dataset.productId,
        name: card.dataset.productName,
        price: Number(card.dataset.productPrice),
      },
    ]),
  );
  const formatter = new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  });
  let cart = {};

  function setStatus(message) {
    cartStatus.textContent = message;
  }

  function saveCart() {
    try {
      localStorage.setItem(storageKey, JSON.stringify(cart));
      setStatus('');
      return true;
    } catch (error) {
      console.error('Keranjang tidak dapat disimpan di browser.', error);
      setStatus('Keranjang tidak dapat disimpan. Coba aktifkan penyimpanan browser.');
      return false;
    }
  }

  function loadCart() {
    try {
      const saved = localStorage.getItem(storageKey);
      if (!saved) return;

      const parsed = JSON.parse(saved);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error('Format data keranjang tidak valid.');
      }

      cart = Object.fromEntries(
        Object.entries(parsed).filter(([id, quantity]) =>
          products.has(id) && Number.isInteger(quantity) && quantity > 0,
        ),
      );
    } catch (error) {
      console.error('Data keranjang tidak dapat dibaca.', error);
      setStatus('Keranjang sebelumnya tidak dapat dibaca. Silakan pilih menu kembali.');
      cart = {};
    }
  }

  function renderCart() {
    cartItems.replaceChildren();
    let itemCount = 0;
    let total = 0;

    for (const [id, quantity] of Object.entries(cart)) {
      const product = products.get(id);
      if (!product) continue;

      itemCount += quantity;
      total += product.price * quantity;

      const item = document.createElement('li');
      item.className = 'cart-item';

      const details = document.createElement('div');
      const name = document.createElement('p');
      name.className = 'cart-item-name';
      name.textContent = product.name;
      const price = document.createElement('p');
      price.className = 'cart-item-price';
      price.textContent = `${formatter.format(product.price)} / item`;
      details.append(name, price);

      const quantityControls = document.createElement('div');
      quantityControls.className = 'cart-quantity';
      const decrease = document.createElement('button');
      decrease.type = 'button';
      decrease.dataset.changeQuantity = '-1';
      decrease.dataset.productId = id;
      decrease.setAttribute('aria-label', `Kurangi ${product.name}`);
      decrease.textContent = '−';
      const count = document.createElement('span');
      count.textContent = String(quantity);
      const increase = document.createElement('button');
      increase.type = 'button';
      increase.dataset.changeQuantity = '1';
      increase.dataset.productId = id;
      increase.setAttribute('aria-label', `Tambah ${product.name}`);
      increase.textContent = '+';
      quantityControls.append(decrease, count, increase);
      item.append(details, quantityControls);
      cartItems.append(item);
    }

    cartCount.textContent = String(itemCount);
    cartTotal.textContent = formatter.format(total);
    cartEmpty.hidden = itemCount > 0;
    checkoutLink.setAttribute('aria-disabled', itemCount > 0 ? 'false' : 'true');

    const message = itemCount > 0
      ? [
          'Halo Kopi Kita, saya ingin memesan:',
          ...Object.entries(cart).map(([id, quantity]) => {
            const product = products.get(id);
            return `- ${product.name} x${quantity} (${formatter.format(product.price * quantity)})`;
          }),
          `Total sementara: ${formatter.format(total)}`,
          '',
          'Mohon konfirmasi pesanan dan harga final. Terima kasih!',
        ].join('\n')
      : '';
    checkoutLink.href = `https://wa.me/6289527907852?text=${encodeURIComponent(message)}`;
  }

  document.addEventListener('click', (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;

    if (target.closest('[data-open-cart]')) {
      cartDialog.showModal();
      return;
    }

    if (target.closest('[data-close-cart]')) {
      cartDialog.close();
      return;
    }

    const addButton = target.closest('[data-add-to-cart]');
    if (addButton) {
      const card = addButton.closest('[data-product-id]');
      const id = card.dataset.productId;
      cart[id] = (cart[id] || 0) + 1;
      saveCart();
      renderCart();
      setStatus(`${products.get(id).name} ditambahkan ke keranjang.`);
      return;
    }

    const quantityButton = target.closest('[data-change-quantity]');
    if (quantityButton) {
      const id = quantityButton.dataset.productId;
      const quantity = (cart[id] || 0) + Number(quantityButton.dataset.changeQuantity);
      if (quantity > 0) {
        cart[id] = quantity;
      } else {
        delete cart[id];
      }
      saveCart();
      renderCart();
    }
  });

  cartDialog.addEventListener('click', (event) => {
    if (event.target === cartDialog) cartDialog.close();
  });

  loadCart();
  renderCart();
})();
