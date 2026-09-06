# Privacy Policy for Broken Bow Vacation Cabins (Cabin Concierge TV)

**Last Updated:** September 6, 2026

This Privacy Policy describes how the **Broken Bow Vacation Cabins** Roku Channel ("Cabin Concierge TV", "the Channel", "we", "us", or "our") processes, displays, and protects information when used on Roku devices installed at our rental properties.

---

## 1. Overview & Purpose

The Channel is a native Roku application designed to serve as an in-cabin digital concierge for guests staying at Broken Bow Vacation Cabins. It provides property details, local area recommendations, weather forecasts, house rules, checkout procedures, and personalized welcome screens.

---

## 2. Information Processed & Displayed

### A. Property & Stay Display Data
The Channel processes and displays property management and stay information, including:
- **Guest Names & Stay Dates:** Personalized welcome greetings displaying guest names (e.g., first and last name) and stay window (check-in and check-out dates) during active reservation periods.
- **Stay Status & Unit Information:** Unit configuration, active reservation status, and property-specific information.
- **House Rules & Checkout Checklists:** Property rules, instructions, and interactive departure checklists.
- **Guest Feedback & Ratings:** Star ratings and optional feedback comments submitted directly through the Roku interface by guests.

### B. Technical & Device Information
- **Roku Device Identification:** Server-issued device credentials and anonymous identifiers required for securely binding the channel instance to a specific property location.
- **Network Transmission Data:** Standard HTTP request headers and IP addresses required for network communications.

---

## 3. Third-Party Services & API Integrations

To deliver its core features, the Channel communicates with trusted third-party service providers via secure HTTPS API connections:

### A. Supabase (Backend & Database Service)
- **Purpose:** Secure database storage, authentication, and API endpoints.
- **Data Shared/Retrieved:** Property details, active reservation metadata (guest names and stay dates), house rules, local recommendations, and guest feedback submissions.
- **Data Protection:** Database Row-Level Security (RLS) policies enforce strict access controls. Guest names and stay dates are accessible strictly during the active reservation stay window (`check_in_at <= NOW() < check_out_at`) and are automatically hidden during turnover periods.

### B. OpenWeather (Weather Information Service)
- **Purpose:** Providing real-time weather conditions and multi-day forecasts for the property location (Broken Bow / Hochatown area).
- **Data Shared/Retrieved:** Geographic coordinates or location query parameter sent to fetch weather data.
- **Security:** API requests are routed through a secure backend proxy (Supabase Edge Function). No personally identifiable information or guest data is ever transmitted to OpenWeather.

---

## 4. How We Use Information

Information processed by the Channel is used exclusively to:
1. Provide guests with customized on-screen welcome information and stay details during their visit.
2. Display relevant local weather forecasts and area recommendations.
3. Assist guests with house rules, hot tub instructions, and departure checklists.
4. Process guest ratings and feedback to improve property amenities and host services.

---

## 5. Data Security & Storage

We implement robust administrative, technical, and physical security measures to protect data:
- **Encrypted Transmission:** All network traffic between the Roku channel, Supabase backend, and APIs uses industry-standard TLS/SSL (HTTPS) encryption.
- **Time-Restricted Display:** Guest names and dates are only loaded and displayed during active reservation windows.
- **Credential Protection:** API keys and sensitive credentials are held in secure environment secrets on the backend and are never exposed in client packages.
- **Device Authorization:** Each installed channel instance uses server-authenticated device security to prevent unauthorized access to guest display data.

---

## 6. Children's Privacy

The Channel does not knowingly collect or target personal information from children under the age of 13. The application operates solely as an ambient display and informational utility within private vacation rental cabins.

---

## 7. Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect updates to the Channel or regulatory requirements. Any modifications will be effective immediately upon posting the updated policy.

---

## 8. Contact Us

If you have any questions or concerns regarding this Privacy Policy or data handling in the Broken Bow Vacation Cabins Roku Channel, please contact property management:

- **Email:** support@hostsync.com
- **Website:** https://brokenbowvacationcabins.com

