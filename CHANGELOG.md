### 1.5.0 - SDK Update & Maintenance Release
- Updated SDK constraints to `>=3.8.0 <4.0.0`
- Updated Flutter environment to `>=3.19.0`
- Updated `flutter_lints` to `^5.0.0`
- Code maintenance and dependency alignment with ecosystem

---

### 1.3.0 - Initial Release & Background Process Specialization
This release marks the initial official release (v1.3.0) of neom_jobs as a new, independent module within the Open Neom ecosystem. This module is introduced to centralize and manage various background processing tasks, enhancing the platform's operational efficiency and data consistency.

Key Architectural & Feature Improvements:

New Module Introduction:

neom_jobs is now a dedicated module for encapsulating and executing background job processes, ensuring a clear separation of concerns from other application functionalities.

This specialization allows for focused development and maintenance of administrative and data-related routines.

Decoupling for Clearer Responsibilities:

Background job logic, previously potentially integrated within other modules (e.g., neom_settings for triggering jobs or neom_core's data layer), has been extracted and centralized here. This improves modularity and clarifies the scope of each module.

Foundational Job Execution:

Includes the createProfileInstrumentsCollection job, designed to optimize data structures for specific functionalities like finding musicians, by aggregating profile and instrument data.

Enhanced Maintainability & Scalability:

As a dedicated and self-contained module, neom_jobs is now easier to maintain, test, and extend for future background tasks (e.g., analytics processing, data synchronization routines).

This aligns perfectly with the overall architectural vision of Open Neom, fostering a more collaborative and efficient development environment for platform operations.

Leverages Core Open Neom Modules:

Built upon neom_core for foundational services (like JobRepository interface) and neom_commons for reusable utilities, ensuring seamless integration within the ecosystem.