# Admin Panel – Payment Links Management

## Table columns
- Title, Type (service/product/package/subscription), Price, Currency, Subscription?, URL, Enabled, UpdatedAt

## Add/Edit form validations
- URL starts with https://buy.stripe.com/
- Price > 0 (display-only; the real price is in Stripe PL)
- Type ∈ {service, product, package, subscription}
- Metadata JSON is valid (if editable)

## Suggested naming convention
- `PL_{CATEGORY}_{NAME}_vYYYY_MM` e.g., `PL_SERV_TAGLIO_DONNA_v2025_10`

## Bulk import
- Use `examples/payment_links_catalog.csv` to seed links per salon.
