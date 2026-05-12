//! strongly typed identifiers.

macro_rules! define_id {
    ($name:ident, $doc:expr) => {
        #[doc = $doc]
        #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
        pub struct $name(pub usize);

        impl $name {
            #[inline]
            pub fn new(id: usize) -> Self {
                Self(id)
            }

            #[inline]
            pub fn inner(self) -> usize {
                self.0
            }
        }

        impl std::fmt::Display for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, "{}({})", stringify!($name), self.0)
            }
        }

        impl From<usize> for $name {
            #[inline]
            fn from(id: usize) -> Self {
                Self(id)
            }
        }

        impl From<$name> for usize {
            #[inline]
            fn from(id: $name) -> Self {
                id.0
            }
        }
    };
}

define_id!(BufferId, "a unique identifier for a text buffer.");
define_id!(
    WindowId,
    "a unique identifier for an operating system window."
);
define_id!(
    NodeId,
    "a unique identifier for a layout node in the taffy engine."
);
define_id!(PanelId, "a unique identifier for a rendered ui panel.");

#[cfg(test)]
mod id_tests {
    use super::*;

    #[test]
    fn id_creation_and_conversion() {
        let buf_id = BufferId::new(42);
        assert_eq!(buf_id.inner(), 42);

        let raw: usize = buf_id.into();
        assert_eq!(raw, 42);

        let new_buf: BufferId = 99.into();
        assert_eq!(new_buf.inner(), 99);
    }
}
